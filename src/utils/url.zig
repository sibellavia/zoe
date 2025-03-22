const std = @import("std");

pub const UrlBuilder = struct {
    allocator: std.mem.Allocator,
    // We don't currently have any fields that need to be freed,
    // but we'll maintain the deinit method for future extensibility

    pub fn init(allocator: std.mem.Allocator) UrlBuilder {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const UrlBuilder) void {
        _ = self;
    }

    // Input: filename (e.g., "my-first-post.md")
    // Output: "/posts/my-first-post/"
    pub fn generatePostUrl(self: *const UrlBuilder, filename: []const u8) ![]const u8 {
        // Remove .md extension
        const basename = if (std.mem.endsWith(u8, filename, ".md"))
            filename[0 .. filename.len - 3]
        else
            filename;

        const result = try std.fmt.allocPrint(
            self.allocator,
            "/posts/{s}/",
            .{basename},
        );
        return result;
    }

    // Input: section_path (e.g., "blog" or "products/software")
    // Output: "/blog/" or "/products/software/"
    pub fn generateSectionUrl(self: *const UrlBuilder, section_path: []const u8) ![]const u8 {
        if (section_path.len == 0) {
            return try self.allocator.dupe(u8, "/");
        }

        const result = try std.fmt.allocPrint(
            self.allocator,
            "/{s}/",
            .{section_path},
        );

        return result;
    }

    // Input: section_path (e.g., "blog"), filename (e.g., "hello-world.md")
    // Output: "/blog/hello-world/"
    pub fn generateContentUrl(self: *const UrlBuilder, section_path: []const u8, filename: []const u8) ![]const u8 {
        // Remove .md extension
        const basename = if (std.mem.endsWith(u8, filename, ".md"))
            filename[0 .. filename.len - 3]
        else
            filename;

        const result = if (section_path.len == 0)
            try std.fmt.allocPrint(
                self.allocator,
                "/{s}/",
                .{basename},
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "/{s}/{s}/",
                .{ section_path, basename },
            );

        return result;
    }

    // Input: filename (e.g., "my-first-post.md")
    // Output: "posts/my-first-post/index.html"
    pub fn generatePostPath(self: *const UrlBuilder, filename: []const u8) ![]const u8 {
        // Remove .md extension
        const basename = if (std.mem.endsWith(u8, filename, ".md"))
            filename[0 .. filename.len - 3]
        else
            filename;

        const result = try std.fmt.allocPrint(
            self.allocator,
            "posts/{s}/index.html",
            .{basename},
        );

        return result;
    }

    // Input: section_path (e.g., "blog" or "products/software")
    // Output: "blog/index.html" or "products/software/index.html"
    pub fn generateSectionPath(self: *const UrlBuilder, section_path: []const u8) ![]const u8 {
        if (section_path.len == 0) {
            return try self.allocator.dupe(u8, "index.html");
        }

        const result = try std.fmt.allocPrint(
            self.allocator,
            "{s}/index.html",
            .{section_path},
        );

        return result;
    }

    // Input: section_path (e.g., "blog"), filename (e.g., "hello-world.md")
    // Output: "blog/hello-world/index.html"
    pub fn generateContentPath(self: *const UrlBuilder, section_path: []const u8, filename: []const u8) ![]const u8 {
        // Remove .md extension
        const basename = if (std.mem.endsWith(u8, filename, ".md"))
            filename[0 .. filename.len - 3]
        else
            filename;

        const result = if (section_path.len == 0)
            try std.fmt.allocPrint(
                self.allocator,
                "{s}/index.html",
                .{basename},
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}/index.html",
                .{ section_path, basename },
            );

        return result;
    }
};
