const std = @import("std");

/// Clean build artifacts
pub fn execute() !void {
    std.debug.print("Cleaning build artifacts...\n", .{});

    // Remove public directory
    std.fs.cwd().deleteTree("public") catch |e| {
        if (e != error.FileNotFound) return e;
    };

    std.debug.print("Clean complete\n", .{});
}
