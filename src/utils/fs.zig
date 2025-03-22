const std = @import("std");
const types = @import("../core/types.zig");
const content = @import("../core/content.zig");
const sitemap = @import("../utils/sitemap.zig");

// *** ERRORS *** //

pub const FsError = error{
    PathAlreadyExists,
    FileNotFound,
    AccessDenied,
    OutOfMemory,
    Unexpected,
};

// *** CONTEXT *** //

pub const FsContext = struct {
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
};

pub const InitializeFilesystemOptions = struct {
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
    assets_dir: []const u8 = "static",
};

pub const SetupDirectoriesOptions = struct {
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
    assets_dir: ?[]const u8 = null,
};

/// Sets up the directory structure needed for building the site.
/// This function creates output directories and copies required assets.
pub fn setupDirectories(options: SetupDirectoriesOptions) !void {
    // Create main output directory
    try createDirIfNotExists(options.output_dir);

    // Create subdirectories
    const posts_dir = try std.fmt.allocPrint(options.allocator, "{s}/posts", .{options.output_dir});
    defer options.allocator.free(posts_dir);
    try createDirIfNotExists(posts_dir);

    const images_dir = try std.fmt.allocPrint(options.allocator, "{s}/images", .{options.output_dir});
    defer options.allocator.free(images_dir);
    try createDirIfNotExists(images_dir);

    // Handle images directory if it exists
    const images_path = try std.fmt.allocPrint(options.allocator, "{s}/images", .{options.input_dir});
    defer options.allocator.free(images_path);

    const images_dest = try std.fmt.allocPrint(options.allocator, "{s}/images", .{options.output_dir});
    defer options.allocator.free(images_dest);

    // Create context for copying
    const ctx = FsContext{
        .allocator = options.allocator,
        .input_dir = options.input_dir,
        .output_dir = options.output_dir,
    };

    // Copy images directory if it exists
    if (std.fs.cwd().openDir(images_path, .{})) |dir_const| {
        var dir = dir_const;
        defer dir.close();
        try copyDir(ctx, images_path, images_dest);
    } else |_| {
        // Images directory doesn't exist, that's okay
    }

    // Handle static assets directory if it exists
    if (options.assets_dir) |static_path| {
        if (std.fs.cwd().openDir(static_path, .{})) |dir_const| {
            var dir = dir_const;
            defer dir.close();

            // Create the static directory in the output
            const static_output = try std.fmt.allocPrint(options.allocator, "{s}/static", .{options.output_dir});
            defer options.allocator.free(static_output);
            try createDirIfNotExists(static_output);

            // Copy static directory to output/static
            try copyDir(ctx, static_path, static_output);
        } else |e| {
            std.log.warn("Static directory not found or could not be accessed: {s}", .{@errorName(e)});
        }
    }
}

pub const WriteOutputOptions = struct {
    allocator: std.mem.Allocator,
    collection: *content.ContentProcessor,
    input_dir: []const u8,
    output_dir: []const u8,
    base_url: []const u8,
};

pub fn WriteOutput(options: WriteOutputOptions) !void {
    // Create output directory if it doesn't exist
    try createDirIfNotExists(options.output_dir);

    // Process the homepage if it exists
    if (options.collection.homepage) |homepage| {
        try writeContentToFile(options.allocator, homepage.output_path, homepage.content, options.output_dir);
    }

    // Process all section content
    var section_it = options.collection.sections.iterator();
    while (section_it.next()) |entry| {
        const section = entry.value_ptr.*;

        // Write section index if it exists
        if (section.index_page) |index| {
            try writeContentToFile(options.allocator, index.output_path, index.content, options.output_dir);
        }

        // Write all pages in the section
        for (section.pages.items) |page| {
            try writeContentToFile(options.allocator, page.output_path, page.content, options.output_dir);
        }
    }

    // Generate sitemap.xml if needed
    try generateSitemap(options);
}

fn writeContentToFile(allocator: std.mem.Allocator, relative_path: []const u8, content_data: []const u8, output_dir: []const u8) !void {
    const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ output_dir, relative_path });
    defer allocator.free(full_path);

    // Create directory structure if needed
    const dir_path = std.fs.path.dirname(full_path) orelse "";
    if (dir_path.len > 0) {
        try std.fs.cwd().makePath(dir_path);
    }

    // Write the file
    const file = try std.fs.cwd().createFile(full_path, .{});
    defer file.close();

    try file.writeAll(content_data);
}

fn generateSitemap(options: WriteOutputOptions) !void {
    // Initialize sitemap generator
    var generator = try sitemap.SitemapGenerator.init(options.allocator, options.base_url);
    defer generator.deinit();

    std.debug.print("Generating sitemap for {s}\n", .{options.base_url});

    // Add homepage to sitemap if it exists
    if (options.collection.homepage) |homepage| {
        try generator.addPage(homepage);
    }

    // Add all sections and pages to the sitemap
    var section_it = options.collection.sections.iterator();
    while (section_it.next()) |entry| {
        const section = entry.value_ptr.*;

        // Add section index if it exists
        if (section.index_page) |index| {
            try generator.addPage(index);
        }

        // Add all pages in the section
        for (section.pages.items) |page| {
            try generator.addPage(page);
        }
    }

    // Write the sitemap to the output directory
    try generator.writeSitemap(options.output_dir);
    std.debug.print("Sitemap generated at {s}/sitemap.xml\n", .{options.output_dir});
}

// *** FUNCTIONS *** //

/// Creates a directory if it doesn't already exist
pub fn createDirIfNotExists(path: []const u8) !void {
    std.fs.cwd().makeDir(path) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

/// Copies a directory recursively
pub fn copyDir(ctx: FsContext, src_dir: []const u8, dest_dir: []const u8) !void {
    var src_dir_entries = try std.fs.cwd().openDir(src_dir, .{ .iterate = true });
    defer src_dir_entries.close();

    var iter = src_dir_entries.iterate();
    while (try iter.next()) |entry| {
        const src = try std.fmt.allocPrint(ctx.allocator, "{s}/{s}", .{ src_dir, entry.name });
        defer ctx.allocator.free(src);

        const dst = try std.fmt.allocPrint(ctx.allocator, "{s}/{s}", .{ dest_dir, entry.name });
        defer ctx.allocator.free(dst);

        switch (entry.kind) {
            .file => try std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}),
            .directory => {
                try createDirIfNotExists(dst);
                try copyDir(ctx, src, dst);
            },
            else => {},
        }
    }
}

/// Check if a file exists
pub fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch {
        return false;
    };
    return true;
}
