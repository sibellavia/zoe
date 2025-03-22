const std = @import("std");
const cli_mod = @import("core/cli.zig");

pub fn main() !void {
    try runWithAllocator();
}

fn runWithAllocator() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        // Check for leaks during deinitialization
        const leaked = gpa.deinit() == .leak;
        if (leaked) {
            std.debug.dumpCurrentStackTrace(@returnAddress());
            std.debug.panic("Memory leak detected", .{});
        }
    }

    const allocator = gpa.allocator();

    // Initialize CLI
    var cli = try cli_mod.Cli.init(allocator);
    defer cli.deinit();

    // Run the command
    try runCommand(&cli);
}

fn runCommand(cli: *cli_mod.Cli) !void {
    cli.run() catch |err| {
        switch (err) {
            error.OutOfMemory => {
                std.log.err("Out of memory. Logging stack trace.", .{});
                std.debug.dumpCurrentStackTrace(@returnAddress());
            },
            error.FileNotFound => {
                std.log.err("File not found: {s}", .{@errorName(err)});
            },
            error.InvalidConfiguration => {
                std.log.err("Invalid configuration. Please check your zoe-config.json file", .{});
            },
            else => {
                std.log.err("Unexpected error: {s}", .{@errorName(err)});
            },
        }
        return err;
    };
}
