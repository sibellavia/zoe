const std = @import("std");
const json = std.json;

pub const ConfigError = error{
    DirectoryNotFound,
    InvalidConfig,
    ParseError,
    MissingField,
    OutOfMemory,
};

const SeoConfig = struct {
    twitter_handle: []const u8,
    twitter_card_type: ?[]const u8 = null,
    default_image: ?[]const u8 = null,
    favicon: ?[]const u8 = null,
    google_analytics: ?[]const u8 = null,
    enable_sitemap: ?bool = null,
    author: ?[]const u8 = null,
    keywords: ?[]const u8 = null,
    // TODO: Add other SEO related config
};

const GithubPagesConfig = struct {
    branch: []const u8,
    cname: ?[]const u8,
};

const BuildConfig = struct {
    // input_dir and templates_dir are now constants
    output_dir: []const u8,
    assets_dir: ?[]const u8,
};

// Constants for fixed directories
const CONTENT_DIR = "content";
const TEMPLATES_DIR = "templates";
const DEFAULT_OUTPUT_DIR = "public";
const ASSETS_DIR = "assets";

pub const SiteConfig = struct {
    // Site metadata
    title: []const u8,
    description: []const u8,
    base_url: []const u8,

    // Build settings
    build: BuildConfig,

    // SEO configuration
    seo: SeoConfig,

    // Github Pages configuration
    github_pages: ?GithubPagesConfig,

    // Store arena for simplified memory management
    arena: std.heap.ArenaAllocator,

    pub fn init(parent_allocator: std.mem.Allocator) !SiteConfig {
        // Create arena allocator
        var arena = std.heap.ArenaAllocator.init(parent_allocator);
        errdefer arena.deinit();

        const allocator = arena.allocator();

        // Verify required directories exist
        std.fs.cwd().access(CONTENT_DIR, .{}) catch |e| {
            return e;
        };

        std.fs.cwd().access(TEMPLATES_DIR, .{}) catch |e| {
            return e;
        };

        // Try to read zoe-config.json
        const config_content = std.fs.cwd().readFileAlloc(allocator, "zoe-config.json", 1024 * 1024) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.debug.print("No configuration file found, using defaults\n", .{});
                    return SiteConfig{
                        .title = try allocator.dupe(u8, "My Site"),
                        .description = try allocator.dupe(u8, "Built with Zoe"),
                        .base_url = try allocator.dupe(u8, "http://localhost:8080"),
                        .build = .{
                            .output_dir = try allocator.dupe(u8, DEFAULT_OUTPUT_DIR),
                            .assets_dir = null,
                        },
                        .seo = .{
                            .twitter_handle = try allocator.dupe(u8, ""),
                            .twitter_card_type = null,
                            .default_image = null,
                            .favicon = null,
                            .google_analytics = null,
                            .enable_sitemap = null,
                            .author = null,
                            .keywords = null,
                        },
                        .github_pages = null,
                        .arena = arena,
                    };
                },
                error.OutOfMemory => return error.OutOfMemory,
                else => {
                    return ConfigError.InvalidConfig;
                },
            }
        };
        // No need to free config_content as it's managed by the arena now

        // Parse JSON
        const parsed = json.parseFromSlice(std.json.Value, allocator, config_content, .{}) catch |e| {
            return e;
        };

        const root = parsed.value.object;

        // Validate and extract required sections
        const site = root.get("site") orelse {
            return ConfigError.MissingField;
        };
        const build = root.get("build") orelse {
            return ConfigError.MissingField;
        };
        const seo = root.get("seo") orelse {
            return ConfigError.MissingField;
        };

        // Extract site configuration
        const site_obj = site.object;
        const title = site_obj.get("title") orelse {
            return ConfigError.MissingField;
        };
        const description = site_obj.get("description") orelse {
            return ConfigError.MissingField;
        };
        const base_url = site_obj.get("base_url") orelse {
            return ConfigError.MissingField;
        };

        // Extract build configuration
        const build_obj = build.object;

        // input_dir and templates_dir are now ignored if present in config
        const output_dir = build_obj.get("output_dir") orelse {
            std.debug.print("No 'output_dir' specified, using default: {s}\n", .{DEFAULT_OUTPUT_DIR});
            // Use default instead of error
            return .{
                .title = try allocator.dupe(u8, title.string),
                .description = try allocator.dupe(u8, description.string),
                .base_url = try allocator.dupe(u8, base_url.string),
                .build = .{
                    .output_dir = try allocator.dupe(u8, DEFAULT_OUTPUT_DIR),
                    .assets_dir = try allocator.dupe(u8, ASSETS_DIR),
                },
                .seo = .{
                    .twitter_handle = try allocator.dupe(u8, ""),
                    .twitter_card_type = null,
                    .default_image = null,
                    .favicon = null,
                    .google_analytics = null,
                    .enable_sitemap = null,
                    .author = null,
                    .keywords = null,
                },
                .github_pages = null,
                .arena = arena,
            };
        };

        // Assets dir is optional
        const assets_dir_value = build_obj.get("assets_dir");
        const assets_dir = if (assets_dir_value) |dir|
            try allocator.dupe(u8, dir.string)
        else
            null;

        // Extract SEO configuration
        const seo_obj = seo.object;
        const twitter_handle = seo_obj.get("twitter_handle") orelse {
            return ConfigError.MissingField;
        };

        // Extract optional SEO fields
        const twitter_card_type = if (seo_obj.get("twitter_card_type")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        const default_image = if (seo_obj.get("default_image")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        const favicon = if (seo_obj.get("favicon")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        const google_analytics = if (seo_obj.get("google_analytics")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        const enable_sitemap = if (seo_obj.get("enable_sitemap")) |val|
            val.bool
        else
            null;

        const author = if (seo_obj.get("author")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        const keywords = if (seo_obj.get("keywords")) |val|
            try allocator.dupe(u8, val.string)
        else
            null;

        // Extract optional GitHub Pages configuration
        const github_pages_value = root.get("github_pages");
        const github_pages_config = if (github_pages_value) |gh_pages| blk: {
            const gh_obj = gh_pages.object;
            const branch = gh_obj.get("branch") orelse {
                return ConfigError.MissingField;
            };
            break :blk GithubPagesConfig{
                .branch = try allocator.dupe(u8, branch.string),
                .cname = if (gh_obj.get("cname")) |cname| try allocator.dupe(u8, cname.string) else null,
            };
        } else null;

        // Construct and return the config
        return SiteConfig{
            .title = try allocator.dupe(u8, title.string),
            .description = try allocator.dupe(u8, description.string),
            .base_url = try allocator.dupe(u8, base_url.string),
            .build = .{
                .output_dir = try allocator.dupe(u8, output_dir.string),
                .assets_dir = assets_dir,
            },
            .seo = .{
                .twitter_handle = try allocator.dupe(u8, twitter_handle.string),
                .twitter_card_type = twitter_card_type,
                .default_image = default_image,
                .favicon = favicon,
                .google_analytics = google_analytics,
                .enable_sitemap = enable_sitemap,
                .author = author,
                .keywords = keywords,
            },
            .github_pages = github_pages_config,
            .arena = arena,
        };
    }

    /// Loads the site configuration from the config file
    pub fn loadConfig(allocator: std.mem.Allocator) !SiteConfig {
        return try SiteConfig.init(allocator);
    }

    /// Free all allocated memory in the config
    pub fn deinit(self: *SiteConfig) void {
        // Simply destroy the arena, freeing all allocations at once
        self.arena.deinit();
    }

    pub fn clone(self: SiteConfig, parent_allocator: std.mem.Allocator) !SiteConfig {
        // Create a new arena for the clone
        var new_arena = std.heap.ArenaAllocator.init(parent_allocator);
        errdefer new_arena.deinit();

        const allocator = new_arena.allocator();

        return SiteConfig{
            .title = try allocator.dupe(u8, self.title),
            .description = try allocator.dupe(u8, self.description),
            .base_url = try allocator.dupe(u8, self.base_url),
            .build = .{
                .output_dir = try allocator.dupe(u8, self.build.output_dir),
                .assets_dir = if (self.build.assets_dir) |assets_dir|
                    try allocator.dupe(u8, assets_dir)
                else
                    null,
            },
            .seo = .{
                .twitter_handle = try allocator.dupe(u8, self.seo.twitter_handle),
                .twitter_card_type = if (self.seo.twitter_card_type) |card_type| try allocator.dupe(u8, card_type) else null,
                .default_image = if (self.seo.default_image) |image| try allocator.dupe(u8, image) else null,
                .favicon = if (self.seo.favicon) |icon| try allocator.dupe(u8, icon) else null,
                .google_analytics = if (self.seo.google_analytics) |analytics| try allocator.dupe(u8, analytics) else null,
                .enable_sitemap = self.seo.enable_sitemap,
                .author = if (self.seo.author) |auth| try allocator.dupe(u8, auth) else null,
                .keywords = if (self.seo.keywords) |key| try allocator.dupe(u8, key) else null,
            },
            .github_pages = if (self.github_pages) |config| .{
                .branch = try allocator.dupe(u8, config.branch),
                .cname = if (config.cname) |cname| try allocator.dupe(u8, cname) else null,
            } else null,
            .arena = new_arena,
        };
    }

    // Utility methods to get fixed directory paths
    pub fn getContentDir() []const u8 {
        return CONTENT_DIR;
    }

    pub fn getTemplatesDir() []const u8 {
        return TEMPLATES_DIR;
    }

    pub fn getOutputDir(self: SiteConfig) []const u8 {
        return self.build.output_dir;
    }

    pub fn getAssetsDir(self: SiteConfig) ?[]const u8 {
        return self.build.assets_dir;
    }
};
