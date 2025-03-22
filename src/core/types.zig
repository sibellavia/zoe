const std = @import("std");

/// The type of content
pub const ContentType = enum {
    page, // Regular content page (including homepage)
    section, // Section page with list of content
};

/// A unified content type for all pages
pub const Content = struct {
    title: []const u8,
    date: []const u8,
    content: []const u8,
    output_path: []const u8,
    url: []const u8,
    content_type: ContentType,
    section_path: ?[]const u8, // Optional section path this content belongs to
    filename: []const u8, // Original filename
    draft: bool = false, // Whether this is a draft page (not included in sitemap)
    pages: ?[]Content = null, // Optional list of pages (for section content)

    // Initialize a new Content with allocated strings
    pub fn create(allocator: std.mem.Allocator, opts: struct {
        title: []const u8,
        date: []const u8,
        content: []const u8,
        output_path: []const u8,
        url: []const u8,
        content_type: ContentType = .page,
        section_path: ?[]const u8 = null,
        filename: []const u8,
        draft: bool = false,
    }) !Content {
        return Content{
            .title = try allocator.dupe(u8, opts.title),
            .date = try allocator.dupe(u8, opts.date),
            .content = try allocator.dupe(u8, opts.content),
            .output_path = try allocator.dupe(u8, opts.output_path),
            .url = try allocator.dupe(u8, opts.url),
            .content_type = opts.content_type,
            .section_path = if (opts.section_path) |path| try allocator.dupe(u8, path) else null,
            .filename = try allocator.dupe(u8, opts.filename),
            .draft = opts.draft,
        };
    }

    // Clone this content
    pub fn clone(self: Content, allocator: std.mem.Allocator) !Content {
        return Content{
            .title = try allocator.dupe(u8, self.title),
            .date = try allocator.dupe(u8, self.date),
            .content = try allocator.dupe(u8, self.content),
            .output_path = try allocator.dupe(u8, self.output_path),
            .url = try allocator.dupe(u8, self.url),
            .content_type = self.content_type,
            .section_path = if (self.section_path) |path| try allocator.dupe(u8, path) else null,
            .filename = try allocator.dupe(u8, self.filename),
            .draft = self.draft,
            .pages = self.pages, // Just copy the reference, cloning pages is handled separately
        };
    }

    // Free all allocated memory
    pub fn deinit(self: *Content, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.date);
        allocator.free(self.content);
        allocator.free(self.output_path);
        allocator.free(self.url);
        allocator.free(self.filename);

        if (self.section_path) |path| {
            allocator.free(path);
        }
    }

    // Helper methods
    pub fn isSection(self: Content) bool {
        return self.content_type == .section;
    }

    pub fn isPage(self: Content) bool {
        return self.content_type == .page;
    }

    pub fn isHomepage(self: Content) bool {
        return self.isPage() and std.mem.eql(u8, self.url, "/");
    }
};

/// Represents a website section (a directory in the content folder)
pub const Section = struct {
    name: []const u8,
    path: []const u8,
    index_page: ?Content = null, // The _index.md page for this section
    pages: std.ArrayList(Content), // Regular pages in this section

    pub fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !*Section {
        const section = try allocator.create(Section);
        errdefer allocator.destroy(section);

        section.* = .{
            .name = try allocator.dupe(u8, name),
            .path = try allocator.dupe(u8, path),
            .pages = std.ArrayList(Content).init(allocator),
        };
        return section;
    }

    pub fn deinit(self: *Section, allocator: std.mem.Allocator) void {
        // Free pages
        for (self.pages.items) |*page| {
            page.deinit(allocator);
        }
        self.pages.deinit();

        // Free index page if exists
        if (self.index_page) |*idx| {
            idx.deinit(allocator);
        }

        // Free section name and path
        allocator.free(self.name);
        allocator.free(self.path);
    }

    pub fn addPage(self: *Section, allocator: std.mem.Allocator, page: Content) !void {
        var page_clone = try page.clone(allocator);
        errdefer page_clone.deinit(allocator);

        try self.pages.append(page_clone);
    }

    pub fn setIndexPage(self: *Section, allocator: std.mem.Allocator, page: Content) !void {
        if (self.index_page != null) {
            return error.SectionIndexAlreadyExists;
        }

        self.index_page = try page.clone(allocator);
    }
};

/// Frontmatter data structure
pub const Frontmatter = struct {
    title: []const u8,
    date: []const u8,
};
