const std = @import("std");
const config = @import("../core/config.zig");
const pipeline_mod = @import("../core/pipeline.zig");
const Pipeline = pipeline_mod.Pipeline;

pub const BuildError = error{
    DirectoryNotFound,
    DirectoryCreationFailed,
    ConfigurationError,
    PipelineInitializationFailed,
    PipelineExecutionFailed,
};

pub const CommandOptions = struct {
    site_name: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
};

/// Build a Zoe static site
pub fn execute(allocator: std.mem.Allocator, options: CommandOptions, version: []const u8) !void {
    std.debug.print("Zoe, version {s}\n", .{version});
    std.debug.print("Starting build...\n", .{});

    // Load configuration directly using SiteConfig.init
    var site_config = config.SiteConfig.init(allocator) catch |err| {
        std.log.err("Failed to load configuration: {s}", .{@errorName(err)});
        return BuildError.ConfigurationError;
    };
    defer site_config.deinit();

    // Verify and create directories
    try ensureDirectories(site_config);

    // Apply CLI options to config
    try applyConfigOverrides(allocator, &site_config, options);

    // Log the actual configuration being used
    if (options.site_name != null or options.base_url != null) {
        std.debug.print("Using CLI overrides:\n", .{});
        if (options.site_name) |name| {
            std.debug.print("  Site name: {s} (overridden from CLI)\n", .{name});
        }
        if (options.base_url) |url| {
            std.debug.print("  Base URL: {s} (overridden from CLI)\n", .{url});
        }
    } else {
        std.debug.print("Using configuration from zoe-config.json:\n", .{});
        std.debug.print("  Site name: {s}\n", .{site_config.title});
        std.debug.print("  Base URL: {s}\n", .{site_config.base_url});
    }

    // Initialize pipeline
    var pipeline = Pipeline.init(allocator, site_config) catch |err| {
        std.log.err("Failed to initialize pipeline: {s}", .{@errorName(err)});
        return BuildError.PipelineInitializationFailed;
    };
    defer pipeline.deinit();

    // Run the pipeline
    pipeline.run() catch |err| {
        std.log.err("Pipeline execution failed: {s}", .{@errorName(err)});
        return BuildError.PipelineExecutionFailed;
    };

    std.debug.print("Build complete\n", .{});
}

fn ensureDirectories(site_config: config.SiteConfig) !void {
    // Check input directory
    const input_dir = config.SiteConfig.getContentDir();
    std.fs.cwd().access(input_dir, .{}) catch |err| {
        std.log.err("Cannot access input directory '{s}': {s}", .{ input_dir, @errorName(err) });
        return BuildError.DirectoryNotFound;
    };

    // Create output directory
    const output_dir = site_config.getOutputDir();
    std.fs.cwd().makePath(output_dir) catch |err| {
        std.log.err("Cannot create output directory '{s}': {s}", .{ output_dir, @errorName(err) });
        return BuildError.DirectoryCreationFailed;
    };

    // Check templates directory
    const templates_dir = config.SiteConfig.getTemplatesDir();
    std.fs.cwd().access(templates_dir, .{}) catch |err| {
        std.log.err("Cannot access templates directory '{s}': {s}", .{ templates_dir, @errorName(err) });
        return BuildError.DirectoryNotFound;
    };
}

fn applyConfigOverrides(allocator: std.mem.Allocator, site_config: *config.SiteConfig, options: CommandOptions) !void {
    if (options.site_name) |name| {
        site_config.title = try allocator.dupe(u8, name);
    }

    if (options.base_url) |url| {
        site_config.base_url = try allocator.dupe(u8, url);
    }
}
