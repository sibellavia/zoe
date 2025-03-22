const std = @import("std");
const types = @import("types.zig");
const ContentType = types.ContentType;
const Content = types.Content;
const Section = types.Section;
const url_utils = @import("../utils/url.zig");
const markdown = @import("markdown.zig");

// Define specific content errors
pub const ContentError = error{
    DirectoryNotFound,
    NotADirectory,
    PermissionDenied,
    FileSystem,
    OutOfMemory,
    InvalidContent,
    ParseError,
    SectionIndexAlreadyExists,
};

/// ContentProcessor manages the loading and organization of all content
pub const ContentProcessor = struct {
    allocator: std.mem.Allocator, // Parent allocator used for the processor itself
    arena: std.heap.ArenaAllocator, // Arena for all internal allocations
    url_builder: url_utils.UrlBuilder,

    /// Root section - contains all pages not in a specific section
    root_section: *Section,

    /// Map of section paths to Section structs
    sections: std.StringHashMap(*Section),

    /// The homepage content
    homepage: ?Content = null,

    /// Initialize a new ContentProcessor
    pub fn init(allocator: std.mem.Allocator) !*ContentProcessor {
        const processor = try allocator.create(ContentProcessor);
        errdefer allocator.destroy(processor);

        // Initialize the arena allocator
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const arena_allocator = arena.allocator();

        // Initialize the URL builder
        const url_builder = url_utils.UrlBuilder.init(arena_allocator);

        // Initialize the root section
        const root_section = try Section.init(arena_allocator, "", "");

        // Initialize the sections map
        var sections = std.StringHashMap(*Section).init(arena_allocator);

        // Add root section to the map
        const root_key = try arena_allocator.dupe(u8, "");
        try sections.put(root_key, root_section);

        processor.* = .{
            .allocator = allocator,
            .arena = arena,
            .url_builder = url_builder,
            .root_section = root_section,
            .sections = sections,
        };

        return processor;
    }

    /// Clean up all allocated resources
    pub fn deinit(self: *ContentProcessor) void {
        // Free all memory at once with the arena
        self.arena.deinit();

        // Free the processor itself - if caller doesn't do it
        self.allocator.destroy(self);
    }

    /// Process all content in the given directory
    pub fn processContent(self: *ContentProcessor, input_dir: []const u8) ContentError!void {
        const arena_allocator = self.arena.allocator();
        const content_dir_path = try std.fmt.allocPrint(arena_allocator, "{s}", .{input_dir});

        // Verify the content directory exists and is accessible
        var dir = std.fs.cwd().openDir(content_dir_path, .{}) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.err("Content directory not found: {s}", .{content_dir_path});
                    return ContentError.DirectoryNotFound;
                },
                error.NotDir => {
                    std.log.err("Path is not a directory: {s}", .{content_dir_path});
                    return ContentError.NotADirectory;
                },
                error.AccessDenied => {
                    std.log.err("Permission denied accessing content directory: {s}", .{content_dir_path});
                    return ContentError.PermissionDenied;
                },
                else => {
                    std.log.err("Error opening content directory {s}: {s}", .{ content_dir_path, @errorName(err) });
                    return ContentError.FileSystem;
                },
            }
        };
        dir.close();

        // Process the content directory
        try self.processDirectory(content_dir_path, null);

        // Process the index file separately if it exists
        const index_path = try std.fmt.allocPrint(arena_allocator, "{s}/index.md", .{content_dir_path});

        // Check if index file exists and process it
        if (std.fs.cwd().access(index_path, .{})) {
            // File exists, process it
            try self.processHomepage(index_path);
        } else |access_err| {
            switch (access_err) {
                error.FileNotFound => {
                    std.log.warn("No index.md file found in content directory. Home page will not be available.", .{});
                    return;
                },
                error.PermissionDenied => {
                    std.log.err("Permission denied accessing index file: {any}", .{index_path});
                    return ContentError.PermissionDenied;
                },
                else => {
                    std.log.err("Error accessing index file {any}: {any}", .{ index_path, @errorName(access_err) });
                    return ContentError.FileSystem;
                },
            }
        }
    }

    /// Process the homepage (index.md in the content directory)
    fn processHomepage(self: *ContentProcessor, path: []const u8) ContentError!void {
        std.debug.print("Processing homepage: {s}\n", .{path});
        const arena_allocator = self.arena.allocator();

        // Parse the Markdown file
        var content = markdown.createContentFromMarkdown(arena_allocator, path) catch |err| {
            switch (err) {
                error.FileNotFound => return ContentError.DirectoryNotFound,
                error.FileReadError => return ContentError.FileSystem,
                error.InvalidFrontmatter => return ContentError.InvalidContent,
                error.ParseError => return ContentError.ParseError,
                error.RenderError => return ContentError.ParseError,
                error.LatexProcessingError => return ContentError.ParseError,
                error.CodeHighlightingError => return ContentError.ParseError,
                error.OutOfMemory => return ContentError.OutOfMemory,
            }
        };

        // Set the appropriate type, URL and output path
        content.content_type = .page;

        content.output_path = try arena_allocator.dupe(u8, "index.html");
        content.url = try arena_allocator.dupe(u8, "/");

        // Ensure pages field is null to avoid dangling references
        content.pages = null;

        // Clone the content before storing it as homepage
        self.homepage = try content.clone(arena_allocator);
    }

    /// Process a directory and all its contents
    fn processDirectory(self: *ContentProcessor, dir_path: []const u8, section_path: ?[]const u8) ContentError!void {
        const arena_allocator = self.arena.allocator();

        // Get or create the section
        const section = try self.getOrCreateSection(section_path);

        // Open the directory
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |e| {
            std.log.err("Failed to open directory {s}: {s}", .{ dir_path, @errorName(e) });
            return ContentError.FileSystem;
        };
        defer dir.close();

        // Collect all entries first
        var entries = std.ArrayList([]const u8).init(arena_allocator);

        // Iterate through the directory entries
        var dir_it = dir.iterate();
        while (true) {
            const entry = dir_it.next() catch |e| {
                std.log.err("Failed to iterate directory {s}: {s}", .{ dir_path, @errorName(e) });
                return ContentError.FileSystem;
            };

            if (entry == null) break;

            // Skip hidden files (starting with .)
            if (entry.?.name.len > 0 and entry.?.name[0] == '.') {
                continue;
            }

            // Skip the already processed homepage - corrected version
            // We want to skip index.md in the root directory (when section_path is null)
            if (section_path == null and std.mem.eql(u8, entry.?.name, "index.md")) {
                continue;
            }

            const full_path = try std.fmt.allocPrint(
                arena_allocator,
                "{s}/{s}",
                .{ dir_path, entry.?.name },
            );
            try entries.append(full_path);
        }

        // First, look for _index.md in this directory
        var has_section_index = false;
        for (entries.items) |entry_path| {
            const basename = std.fs.path.basename(entry_path);
            if (std.mem.eql(u8, basename, "_index.md")) {
                try self.processSectionIndex(entry_path, section_path, section);
                has_section_index = true;
                break;
            }
        }

        // Then process subdirectories
        for (entries.items) |entry_path| {
            const basename = std.fs.path.basename(entry_path);

            // Skip already processed _index.md
            if (std.mem.eql(u8, basename, "_index.md")) {
                continue;
            }

            const is_dir = isDirectory(entry_path);

            if (is_dir) {
                // Construct the subsection path
                const subsection_path = if (section_path) |s|
                    try std.fmt.allocPrint(arena_allocator, "{s}/{s}", .{ s, basename })
                else
                    try arena_allocator.dupe(u8, basename);

                // Process the subdirectory
                try self.processDirectory(entry_path, subsection_path);
            } else if (std.mem.endsWith(u8, basename, ".md")) {
                // Process regular Markdown file
                try self.processContentFile(entry_path, section_path, section);
            }
        }
    }

    /// Process a section index file (_index.md)
    fn processSectionIndex(self: *ContentProcessor, path: []const u8, section_path: ?[]const u8, section: *Section) ContentError!void {
        std.debug.print("Processing section index: {s} for section: {?s}\n", .{ path, section_path });
        const arena_allocator = self.arena.allocator();

        // Parse the Markdown file
        var content = markdown.createContentFromMarkdown(arena_allocator, path) catch |err| {
            switch (err) {
                error.FileNotFound => return ContentError.DirectoryNotFound,
                error.FileReadError => return ContentError.FileSystem,
                error.InvalidFrontmatter => return ContentError.InvalidContent,
                error.ParseError => return ContentError.ParseError,
                error.RenderError => return ContentError.ParseError,
                error.LatexProcessingError => return ContentError.ParseError,
                error.CodeHighlightingError => return ContentError.ParseError,
                error.OutOfMemory => return ContentError.OutOfMemory,
            }
        };

        // Set the content type to section
        content.content_type = .section;

        content.section_path = if (section_path) |s| try arena_allocator.dupe(u8, s) else null;

        // Generate the URL and output path
        const section_url = if (section_path) |s|
            try std.fmt.allocPrint(arena_allocator, "/{s}/", .{s})
        else
            try arena_allocator.dupe(u8, "/");

        content.url = section_url;

        const output_path = if (section_path) |s|
            try std.fmt.allocPrint(arena_allocator, "{s}/index.html", .{s})
        else
            try arena_allocator.dupe(u8, "index.html");

        content.output_path = output_path;

        // Set as section index
        section.setIndexPage(arena_allocator, content) catch |err| {
            switch (err) {
                error.SectionIndexAlreadyExists => {
                    std.log.err("Section already has an index page: {s}", .{section_path orelse "root"});
                    return ContentError.SectionIndexAlreadyExists;
                },
                else => {
                    std.log.err("Error setting section index page: {s}", .{@errorName(err)});
                    return ContentError.FileSystem;
                },
            }
        };
    }

    /// Process a regular content file
    fn processContentFile(self: *ContentProcessor, path: []const u8, section_path: ?[]const u8, section: *Section) ContentError!void {
        const filename = std.fs.path.basename(path);
        std.debug.print("Processing content file: {s} in section: {?s}\n", .{ filename, section_path });
        const arena_allocator = self.arena.allocator();

        // Parse the Markdown file
        var content = markdown.createContentFromMarkdown(arena_allocator, path) catch |err| {
            switch (err) {
                error.FileNotFound => return ContentError.DirectoryNotFound,
                error.FileReadError => return ContentError.FileSystem,
                error.InvalidFrontmatter => return ContentError.InvalidContent,
                error.ParseError => return ContentError.ParseError,
                error.RenderError => return ContentError.ParseError,
                error.LatexProcessingError => return ContentError.ParseError,
                error.CodeHighlightingError => return ContentError.ParseError,
                error.OutOfMemory => return ContentError.OutOfMemory,
            }
        };

        // Set content type
        content.content_type = .page;

        content.section_path = if (section_path) |s| try arena_allocator.dupe(u8, s) else null;

        // Generate slug from filename (remove .md extension)
        const slug = filename[0 .. filename.len - 3];

        // Generate URL and output path
        const url = if (section_path) |s|
            try std.fmt.allocPrint(arena_allocator, "/{s}/{s}/", .{ s, slug })
        else
            try std.fmt.allocPrint(arena_allocator, "/{s}/", .{slug});

        content.url = url;

        const output_path = if (section_path) |s|
            try std.fmt.allocPrint(arena_allocator, "{s}/{s}/index.html", .{ s, slug })
        else
            try std.fmt.allocPrint(arena_allocator, "{s}/index.html", .{slug});

        content.output_path = output_path;

        // Add to the section
        try section.addPage(arena_allocator, content);
    }

    /// Get an existing section or create a new one
    fn getOrCreateSection(self: *ContentProcessor, section_path: ?[]const u8) ContentError!*Section {
        const arena_allocator = self.arena.allocator();

        // Check if section already exists
        if (section_path) |path| {
            if (self.sections.get(path)) |section| {
                return section;
            }
        } else {
            return self.root_section;
        }

        // Find the last "/" to determine parent section and section name
        var last_slash_idx: ?usize = null;
        for (section_path.?, 0..) |char, i| {
            if (char == '/') {
                last_slash_idx = i;
            }
        }

        const section_name = if (last_slash_idx) |idx|
            section_path.?[idx + 1 ..]
        else
            section_path.?;

        // Create the section
        const section = try Section.init(arena_allocator, section_name, section_path.?);

        // Add to sections map
        const path_copy = if (section_path) |s| try arena_allocator.dupe(u8, s) else try arena_allocator.dupe(u8, "");

        try self.sections.put(path_copy, section);

        return section;
    }

    /// Get all content as a flat array (useful for rendering)
    /// Note: The returned slice is arena-allocated and valid only until deinit() is called.
    /// Any use of this slice after ContentProcessor.deinit() results in undefined behavior.
    pub fn getAllContent(self: *ContentProcessor) ContentError![]Content {
        const arena_allocator = self.arena.allocator();
        var all_content = std.ArrayList(Content).init(arena_allocator);

        // Add homepage if it exists
        if (self.homepage) |homepage| {
            // Create a new homepage copy with pages explicitly set to null
            var homepage_copy = try homepage.clone(arena_allocator);
            homepage_copy.pages = null; // Ensure pages is explicitly null to avoid dangling references
            try all_content.append(homepage_copy);
        }

        // Iterate through all sections
        var it = self.sections.iterator();
        while (it.next()) |entry| {
            const section = entry.value_ptr.*;

            // Add section index if it exists
            if (section.index_page) |index_page| {
                try all_content.append(try index_page.clone(arena_allocator));
            }

            // Add all pages in the section
            for (section.pages.items) |page| {
                try all_content.append(try page.clone(arena_allocator));
            }
        }

        // Sort content by date (newest first)
        const slice = all_content.items;
        std.mem.sort(Content, slice, {}, compareDatesDesc);

        return all_content.toOwnedSlice();
    }
};

/// Compare function for sorting content by date (descending order)
fn compareDatesDesc(_: void, a: Content, b: Content) bool {
    // Return true if a should come before b (a is newer than b)
    return std.mem.order(u8, a.date, b.date) == .gt;
}

/// Check if the given path is a directory
fn isDirectory(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch |e| {
        std.log.err("Failed to open {s}: {s}", .{ path, @errorName(e) });
        return false;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        std.log.err("Failed to stat {s}: {s}", .{ path, @errorName(e) });
        return false;
    };
    return stat.kind == .directory;
}
