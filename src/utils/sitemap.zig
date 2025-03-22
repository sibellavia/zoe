const std = @import("std");
const types = @import("../core/types.zig");

pub const SitemapEntry = struct {
    url: []const u8,
    lastmod: ?[]const u8,
    priority: f32,
    changefreq: []const u8,
};

/// A basic change frequency enum for sitemap entries
pub const ChangeFrequency = enum(u8) {
    always,
    hourly,
    daily,
    weekly,
    monthly,
    yearly,
    never,

    /// Convert enum to string representation for XML
    pub fn toString(self: ChangeFrequency) []const u8 {
        return switch (self) {
            .always => "always",
            .hourly => "hourly",
            .daily => "daily",
            .weekly => "weekly",
            .monthly => "monthly",
            .yearly => "yearly",
            .never => "never",
        };
    }
};

pub const SitemapGenerator = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(SitemapEntry),
    hostname: []const u8,

    pub fn init(allocator: std.mem.Allocator, hostname: []const u8) !SitemapGenerator {
        return SitemapGenerator{
            .allocator = allocator,
            .entries = std.ArrayList(SitemapEntry).init(allocator),
            .hostname = try allocator.dupe(u8, hostname),
        };
    }

    pub fn deinit(self: *SitemapGenerator) void {
        // Clean up all entries
        for (self.entries.items) |entry| {
            self.allocator.free(entry.url);
            if (entry.lastmod) |lastmod| {
                self.allocator.free(lastmod);
            }
            self.allocator.free(entry.changefreq);
        }
        self.entries.deinit();
        self.allocator.free(self.hostname);
    }

    pub fn addEntry(self: *SitemapGenerator, entry: SitemapEntry) !void {
        const new_entry = SitemapEntry{
            .url = try self.allocator.dupe(u8, entry.url),
            .lastmod = entry.lastmod, // This is already duped or null from caller
            .priority = entry.priority,
            .changefreq = try self.allocator.dupe(u8, entry.changefreq),
        };
        try self.entries.append(new_entry);
    }

    pub fn addPage(self: *SitemapGenerator, page: types.Content) !void {
        // Skip draft pages
        if (page.draft) {
            return;
        }

        // Build the full URL
        const full_url = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ self.hostname, page.url },
        );
        defer self.allocator.free(full_url);

        // Determine content priority based on type
        var priority: f32 = 0.5; // Default priority
        if (page.content_type == .page) {
            priority = if (page.isHomepage()) 1.0 else 0.6;
        } else if (page.content_type == .section) {
            priority = 0.8;
        }

        // Get change frequency
        const freq = determineChangeFreq(page);
        const freq_str = freq.toString();

        // Create lastmod string only if date exists
        const lastmod = if (page.date.len > 0)
            try self.allocator.dupe(u8, page.date)
        else
            null;

        // Add the entry to sitemap
        try self.addEntry(.{
            .url = full_url,
            .lastmod = lastmod,
            .priority = priority,
            .changefreq = freq_str,
        });
    }

    // Helper function to determine change frequency based on content type
    fn determineChangeFreq(page: types.Content) ChangeFrequency {
        return switch (page.content_type) {
            .page => if (page.isHomepage()) .weekly else .monthly,
            .section => .weekly,
        };
    }

    pub fn generate(self: *const SitemapGenerator) ![]const u8 {
        var xml = std.ArrayList(u8).init(self.allocator);
        defer xml.deinit();

        try xml.appendSlice(
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            \\
        );

        for (self.entries.items) |entry| {
            try xml.appendSlice("<url>\n");
            try xml.writer().print("  <loc>{s}</loc>\n", .{entry.url});

            if (entry.lastmod) |lastmod| {
                try xml.writer().print("  <lastmod>{s}</lastmod>\n", .{lastmod});
            }

            try xml.writer().print("  <changefreq>{s}</changefreq>\n", .{entry.changefreq});
            try xml.writer().print("  <priority>{d:.1}</priority>\n", .{entry.priority});
            try xml.appendSlice("</url>\n");
        }

        try xml.appendSlice("</urlset>\n");
        return xml.toOwnedSlice();
    }

    pub fn writeSitemap(self: *const SitemapGenerator, output_dir: []const u8) !void {
        const sitemap_content = try self.generate();
        defer self.allocator.free(sitemap_content);

        const sitemap_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sitemap.xml",
            .{output_dir},
        );
        defer self.allocator.free(sitemap_path);

        const file = try std.fs.cwd().createFile(sitemap_path, .{});
        defer file.close();

        try file.writeAll(sitemap_content);
    }
};
