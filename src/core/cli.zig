const std = @import("std");
const commands = @import("../cmd/commands.zig");

const VERSION = "0.1.0";

pub const CliError = error{
    UnknownCommand,
    InvalidPort,
    MissingArgument,
};

pub const Command = enum {
    build,
    serve,
    version,
    init,
    clean,
    help,

    pub fn fromString(str: []const u8) ?Command {
        const command_map = .{
            .{ "build", Command.build },
            .{ "serve", Command.serve },
            .{ "init", Command.init },
            .{ "clean", Command.clean },
            .{ "--version", Command.version },
            .{ "--help", Command.help },
        };

        inline for (command_map) |entry| {
            if (std.mem.eql(u8, str, entry[0])) {
                return entry[1];
            }
        }

        return null;
    }
};

pub const CommandOptions = struct {
    port: u16 = 8080,
    site_name: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
};

pub const Cli = struct {
    allocator: std.mem.Allocator,
    args: std.process.ArgIterator,
    verbose: bool,
    command: Command,
    options: CommandOptions,

    pub fn init(allocator: std.mem.Allocator) !Cli {
        var args = try std.process.argsWithAllocator(allocator);
        // Skip the program name
        _ = args.skip();

        // Get the command (if any)
        const cmd_str = args.next();
        // If no command provided, default to help
        const command = if (cmd_str) |str|
            Command.fromString(str) orelse {
                std.log.err("Unknown command: {s}", .{str});
                return CliError.UnknownCommand;
            }
        else
            .help;

        // Parse flags and options
        var verbose = false;
        var options = CommandOptions{};

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
                verbose = true;
                continue;
            }

            // Handle options that require additional arguments
            if (parseOption(&args, arg, &options)) |_| {
                continue;
            } else |err| {
                switch (err) {
                    CliError.MissingArgument => {
                        std.log.err("Missing argument for option: {s}", .{arg});
                        return err;
                    },
                    CliError.InvalidPort => {
                        std.log.err("Invalid port specified. Must be a number between 0-65535", .{});
                        return err;
                    },
                    else => return err,
                }
            }
        }

        return Cli{
            .allocator = allocator,
            .args = args,
            .verbose = verbose,
            .command = command,
            .options = options,
        };
    }

    fn parseOption(args: *std.process.ArgIterator, arg: []const u8, options: *CommandOptions) !bool {
        if (std.mem.eql(u8, arg, "--port") or std.mem.eql(u8, arg, "-p")) {
            const port_str = args.next() orelse {
                return CliError.MissingArgument;
            };
            options.port = std.fmt.parseInt(u16, port_str, 10) catch {
                return CliError.InvalidPort;
            };
            return true;
        }

        if (std.mem.eql(u8, arg, "--name") or std.mem.eql(u8, arg, "-n")) {
            options.site_name = args.next() orelse {
                return CliError.MissingArgument;
            };
            return true;
        }

        if (std.mem.eql(u8, arg, "--base-url")) {
            options.base_url = args.next() orelse {
                return CliError.MissingArgument;
            };
            return true;
        }

        return false;
    }

    pub fn deinit(self: *Cli) void {
        self.args.deinit();
    }

    pub fn run(self: *Cli) !void {
        switch (self.command) {
            .version => commands.utils.showVersion(VERSION),
            .help => commands.utils.showHelp(VERSION),
            .serve => {
                std.debug.print("Starting server on port {d}\n", .{self.options.port});
                try commands.serve.execute(self.allocator, self.options.port, VERSION);
            },
            .build => {
                try commands.build.execute(self.allocator, .{
                    .site_name = self.options.site_name,
                    .base_url = self.options.base_url,
                }, VERSION);
            },
            .init => {
                std.debug.print("Initializing new site\n", .{});
                try commands.init.execute(.{
                    .site_name = self.options.site_name,
                    .base_url = self.options.base_url,
                });
            },
            .clean => {
                std.debug.print("Cleaning build artifacts\n", .{});
                try commands.clean.execute();
            },
        }
    }
};
