const std = @import("std");
const types = @import("types.zig");
const url = @import("../utils/url.zig");
const fs = @import("../utils/fs.zig");
const config = @import("config.zig");
const content_mod = @import("content.zig");

/// Define the different types of templates for various content types
pub const TemplateType = enum {
    base, // For generic pages
    list, // For section pages that list contents
    post, // For blog posts

    /// Get the filename for this template type
    pub fn filename(self: TemplateType) []const u8 {
        return switch (self) {
            .base => "base.html",
            .list => "list.html",
            .post => "post.html",
        };
    }

    /// Determine the appropriate template type for a content item
    pub fn fromContent(content_item: types.Content) TemplateType {
        if (content_item.isSection()) return .list;
        if (content_item.isHomepage()) return .base;
        return .post; // All other content uses post template
    }
};

/// Data structure for template placeholders
const TemplateData = struct {
    title: []const u8,
    date: []const u8,
    content: []const u8,
    url: []const u8,
    section: ?[]const u8 = null,
    pages: ?[]types.Content = null,
    config: ?config.SiteConfig = null,
};

/// Represents a loaded template file
const Template = struct {
    content: []const u8,
    allocator: std.mem.Allocator,

    /// Load a template from a file
    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Template {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        errdefer allocator.free(file_content);

        return Template{
            .content = file_content,
            .allocator = allocator,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Template) void {
        self.allocator.free(self.content);
    }

    /// Process a template with data and return the result
    /// Uses the provided arena_allocator for all allocations, which will be freed automatically
    /// when the arena is reset
    pub fn process(self: *Template, arena_allocator: std.mem.Allocator, data: TemplateData) ![]const u8 {
        var result = std.ArrayList(u8).init(arena_allocator);
        errdefer result.deinit();

        // Process the template content
        try self.processContent(&result, self.content, data);

        return result.toOwnedSlice();
    }

    /// Process part of a template and append to result
    fn processContent(self: *Template, result: *std.ArrayList(u8), content_slice: []const u8, data: TemplateData) !void {
        var i: usize = 0;
        while (i < content_slice.len) {
            // Check for each block
            if (self.findEachBlock(content_slice[i..])) |each_block| {
                // Process content before the each block
                try self.processContent(result, content_slice[i .. i + each_block.start], data);

                // Process the each block if we have pages data
                if (data.pages) |pages| {
                    for (pages) |page| {
                        // Process the each block's inner template
                        try self.processItemTemplate(result, each_block.inner, page);
                    }
                }

                // Skip past the each block
                i += each_block.end;
            }
            // Check for placeholders
            else if (self.findPlaceholder(content_slice[i..])) |placeholder| {
                try self.appendPlaceholderValue(result, placeholder.name, data);
                i += placeholder.len;
            }
            // Regular content
            else {
                try result.append(content_slice[i]);
                i += 1;
            }
        }
    }

    /// Find a {{#each pages}} block if present at the start of the content
    fn findEachBlock(_: *const Template, content_str: []const u8) ?struct { start: usize, end: usize, inner: []const u8 } {
        if (content_str.len < 13 or !std.mem.startsWith(u8, content_str, "{{#each pages")) {
            return null;
        }

        // Find the closing }} of the opening tag
        var tag_end: usize = 13;
        while (tag_end < content_str.len) {
            if (tag_end + 1 < content_str.len and content_str[tag_end] == '}' and content_str[tag_end + 1] == '}') {
                tag_end += 2;
                break;
            }
            tag_end += 1;
        }

        // Find the matching {{/each}} tag
        var depth: usize = 1;
        var block_end: usize = tag_end;

        while (block_end < content_str.len and depth > 0) {
            if (block_end + 9 <= content_str.len and std.mem.eql(u8, content_str[block_end .. block_end + 9], "{{#each ")) {
                depth += 1;
                block_end += 9;
            } else if (block_end + 9 <= content_str.len and std.mem.eql(u8, content_str[block_end .. block_end + 9], "{{/each}}")) {
                depth -= 1;
                if (depth == 0) {
                    return .{
                        .start = 0,
                        .end = block_end + 9,
                        .inner = content_str[tag_end..block_end],
                    };
                }
                block_end += 9;
            } else {
                block_end += 1;
            }
        }

        // No matching end tag found
        return null;
    }

    /// Process a template for an individual item in an each loop
    fn processItemTemplate(_: *const Template, result: *std.ArrayList(u8), template: []const u8, item: types.Content) !void {
        var i: usize = 0;
        while (i < template.len) {
            // Check for item property placeholders
            if (i + 10 < template.len and std.mem.startsWith(u8, template[i..], "{{this.url}}")) {
                try result.appendSlice(item.url);
                i += 12; // Skip past {{this.url}}
            } else if (i + 12 < template.len and std.mem.startsWith(u8, template[i..], "{{this.title}}")) {
                try result.appendSlice(item.title);
                i += 14; // Skip past {{this.title}}
            } else if (i + 11 < template.len and std.mem.startsWith(u8, template[i..], "{{this.date}}")) {
                try result.appendSlice(item.date);
                i += 13; // Skip past {{this.date}}
            } else {
                try result.append(template[i]);
                i += 1;
            }
        }
    }

    /// Skip to the end of a placeholder (past the closing }})
    fn skipToEndOfPlaceholder(_: *const Template, content_str: []const u8) usize {
        var i: usize = 0;
        var found_first = false;

        while (i < content_str.len) {
            if (content_str[i] == '}') {
                if (found_first) {
                    return i + 1;
                }
                found_first = true;
            } else {
                found_first = false;
            }
            i += 1;
        }

        return i;
    }

    /// Find a placeholder if present at the start of the content
    fn findPlaceholder(_: *const Template, content_str: []const u8) ?struct { name: []const u8, len: usize } {
        const placeholders = [_][]const u8{ "title", "content", "date", "url" };

        // Handle {{placeholder}} style
        if (content_str.len > 4 and content_str[0] == '{' and content_str[1] == '{') {
            for (placeholders) |name| {
                // Create marker directly with string concatenation
                const suffix = "}}";
                if (std.mem.startsWith(u8, content_str[2..], name) and
                    content_str.len >= 2 + name.len + 2 and
                    std.mem.eql(u8, content_str[2 + name.len .. 2 + name.len + 2], suffix))
                {
                    return .{ .name = name, .len = 2 + name.len + 2 };
                }
            }
        }

        // Handle {placeholder} style
        if (content_str.len > 2 and content_str[0] == '{') {
            for (placeholders) |name| {
                // Create marker directly
                if (std.mem.startsWith(u8, content_str[1..], name) and
                    content_str.len >= 1 + name.len + 1 and
                    content_str[1 + name.len] == '}')
                {
                    return .{ .name = name, .len = 1 + name.len + 1 };
                }
            }
        }

        return null;
    }

    /// Append the value for a placeholder to the result
    fn appendPlaceholderValue(_: *Template, result: *std.ArrayList(u8), name: []const u8, data: TemplateData) !void {
        if (std.mem.eql(u8, name, "title")) {
            try result.appendSlice(data.title);
        } else if (std.mem.eql(u8, name, "content")) {
            try result.appendSlice(data.content);
        } else if (std.mem.eql(u8, name, "date")) {
            try result.appendSlice(data.date);
        } else if (std.mem.eql(u8, name, "url")) {
            try result.appendSlice(data.url);
        }
    }
};

/// Template manager responsible for loading, caching, and applying templates
pub const TemplateManager = struct {
    allocator: std.mem.Allocator, // For long-lived resources like templates
    arena_allocator: std.mem.Allocator, // Arena allocator from ContentProcessor for temporary allocations
    templates_dir: []const u8,
    templates: std.AutoHashMap(TemplateType, Template),
    config: ?config.SiteConfig = null,

    const Self = @This();

    /// Initialize a new template manager
    /// allocator: Used for long-lived resources (template cache)
    /// arena_allocator: From ContentProcessor, used for temporary allocations
    /// templates_dir: Directory containing template files
    pub fn init(allocator: std.mem.Allocator, arena_allocator: std.mem.Allocator, templates_dir: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .arena_allocator = arena_allocator,
            .templates_dir = try allocator.dupe(u8, templates_dir),
            .templates = std.AutoHashMap(TemplateType, Template).init(allocator),
            .config = null,
        };
        return self;
    }

    /// Set the site configuration
    pub fn setConfig(self: *Self, site_config: config.SiteConfig) void {
        self.config = site_config;
    }

    /// Free all resources
    pub fn deinit(self: *Self) void {
        // Free all templates in the cache
        var it = self.templates.iterator();
        while (it.next()) |entry| {
            var template = entry.value_ptr;
            template.deinit();
        }
        self.templates.deinit();

        // Free the templates directory path
        self.allocator.free(self.templates_dir);

        // Free self
        self.allocator.destroy(self);
    }

    /// Get a template by type, loading it if necessary
    fn getTemplate(self: *Self, template_type: TemplateType) !Template {
        // Check if the template is already in the cache
        if (self.templates.get(template_type)) |template| {
            return template;
        }

        // Try to load the requested template
        const template_path = try self.buildTemplatePath(template_type);
        defer self.allocator.free(template_path);

        // Check if the template file exists
        if (!fs.fileExists(template_path)) {
            if (template_type == .base) {
                std.log.err("Required base.html template not found", .{});
                return error.RequiredTemplateNotFound;
            }
            // Fallback to base template if the specific one doesn't exist
            std.debug.print("Template {s} not found, falling back to base template\n", .{template_type.filename()});
            return try self.getTemplate(.base);
        }

        // Load the template
        var template = try Template.init(self.allocator, template_path);
        errdefer template.deinit();

        // Store in cache
        try self.templates.put(template_type, template);

        return template;
    }

    /// Build the path to a template file
    fn buildTemplatePath(self: *Self, template_type: TemplateType) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ self.templates_dir, template_type.filename() },
        );
    }

    /// Apply a template to a content page
    /// Note: This function DOES NOT free the existing page.content as it's assumed
    /// to be managed by the arena allocator in ContentProcessor
    pub fn applyTemplate(self: *Self, page: *types.Content) !void {
        // Determine which template to use
        const template_type = TemplateType.fromContent(page.*);

        // Get the template
        var template = try self.getTemplate(template_type);

        // Create template data using the page's existing pages data if available
        const data = TemplateData{
            .title = page.title,
            .date = page.date,
            .content = page.content,
            .url = page.url,
            .section = page.section_path,
            .pages = page.pages, // Use the pages data if it was set
            .config = self.config,
        };

        // Process the template
        const rendered = try template.process(self.arena_allocator, data);

        // Replace the page content - no need to free the old content
        // as it's managed by the arena allocator
        page.content = rendered;
    }
};

/// Apply templates to all content in the content processor
/// Note: Memory for temporary allocations comes from content_processor's arena allocator
/// and will be freed automatically when content_processor.deinit() is called
pub fn applyTemplates(content_processor: *content_mod.ContentProcessor, template_manager: *TemplateManager) !void {
    // Apply template to the homepage if it exists
    if (content_processor.homepage) |*homepage| {
        try template_manager.applyTemplate(homepage);
    }

    // Process all sections and their content
    var section_it = content_processor.sections.iterator();
    while (section_it.next()) |entry| {
        const section = entry.value_ptr.*;

        // Apply template to section index if it exists
        if (section.index_page) |*index| {
            // Create pages data for the section template
            // This array is allocated in the arena and will be automatically freed
            const pages_data = try getPages(section, template_manager.arena_allocator);

            // Set pages data and apply template
            index.pages = pages_data;
            try template_manager.applyTemplate(index);
            index.pages = null; // Clear reference to avoid confusion, but no need to free
        }

        // Apply templates to all pages in the section
        for (section.pages.items) |*page| {
            try template_manager.applyTemplate(page);
        }
    }
}

/// Helper function to get all pages from a section
fn getPages(section: *types.Section, allocator: std.mem.Allocator) ![]types.Content {
    var result = std.ArrayList(types.Content).init(allocator);
    // No errdefer needed with arena allocator

    for (section.pages.items) |page| {
        try result.append(try page.clone(allocator));
    }

    // Sort pages by date (newest first)
    const slice = result.items;
    std.mem.sort(types.Content, slice, {}, compareDatesDesc);

    return result.toOwnedSlice();
}

/// Compare function for sorting content by date (descending order)
fn compareDatesDesc(_: void, a: types.Content, b: types.Content) bool {
    // Return true if a should come before b (a is newer than b)
    return std.mem.order(u8, a.date, b.date) == .gt;
}
