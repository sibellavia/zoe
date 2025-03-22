const std = @import("std");
const server = @import("../server/server.zig");
const config = @import("../core/config.zig");
const pipeline_mod = @import("../core/pipeline.zig");
const Pipeline = pipeline_mod.Pipeline;

/// Start a development server for the Zoe site
pub fn execute(allocator: std.mem.Allocator, port: u16, version: []const u8) !void {
    std.debug.print("Zoe, version {s}\n", .{version});
    std.debug.print("Starting Server on port {d}\n", .{port});

    // Ensure required directories exist
    const input_dir = config.SiteConfig.getContentDir();
    std.fs.cwd().access(input_dir, .{}) catch |e| {
        std.log.err("Cannot access input directory '{s}': {s}", .{ input_dir, @errorName(e) });
        return error.DirectoryNotFound;
    };

    const templates_dir = config.SiteConfig.getTemplatesDir();
    std.fs.cwd().access(templates_dir, .{}) catch |e| {
        std.log.err("Cannot access templates directory '{s}': {s}", .{ templates_dir, @errorName(e) });
        return error.DirectoryNotFound;
    };

    // The server initialization will handle building the site
    try server.serve(allocator, port);
}
