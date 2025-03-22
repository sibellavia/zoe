const std = @import("std");
const config = @import("../core/config.zig");
const pipeline_mod = @import("../core/pipeline.zig");
const Pipeline = pipeline_mod.Pipeline;
const Allocator = std.mem.Allocator;

pub const Server = struct {
    allocator: Allocator,
    server: std.net.Server,
    running: bool,
    cwd_absolute_path: []const u8,
    port: u16,
    site_config: config.SiteConfig,
    pipeline: Pipeline,

    pub fn init(allocator: Allocator, port: u16) !*Server {
        // Create address and server
        const address = try std.net.Address.parseIp("127.0.0.1", port);
        const server = try address.listen(.{});

        // Get the absolute path
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        const cwd_path = try std.fs.cwd().realpath(".", &buffer);
        const cwd_absolute_path = try allocator.dupe(u8, cwd_path);

        // Load site configuration
        const site_config = try config.SiteConfig.init(allocator);
        // Create a clone of the config for the pipeline
        const pipeline_config = try site_config.clone(allocator);

        // Initialize pipeline with the cloned config
        const pipeline = try Pipeline.init(allocator, pipeline_config);

        const self = try allocator.create(Server);
        self.* = .{
            .allocator = allocator,
            .server = server,
            .running = false,
            .cwd_absolute_path = cwd_absolute_path,
            .port = port,
            .site_config = site_config,
            .pipeline = pipeline,
        };

        return self;
    }

    pub fn deinit(self: *Server) void {
        self.pipeline.deinit();
        self.site_config.deinit();
        self.allocator.free(self.cwd_absolute_path);
        self.server.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *Server) !void {
        std.debug.print("Starting server initialization...\n", .{});

        // Initial site generation
        try self.pipeline.run();

        std.debug.print("\n=== Server Status ===\n", .{});
        std.debug.print("Listening on: http://localhost:{}\n", .{self.port});
        std.debug.print("Serving files from: {s}\n", .{self.cwd_absolute_path});
        std.debug.print("Press Ctrl+C to stop\n", .{});

        self.running = true;

        while (self.running) {
            std.debug.print("Waiting for connections...\n", .{});
            const connection = self.server.accept() catch |err| {
                switch (err) {
                    error.ConnectionAborted, error.ConnectionResetByPeer => continue,
                    else => {
                        std.log.err("Server error: {}", .{err});
                        return err;
                    },
                }
            };
            std.debug.print("Received connection, handling...\n", .{});

            self.handleConnection(connection) catch |err| {
                std.log.err("Error handling connection: {}", .{err});
                continue;
            };
        }
    }

    fn handleConnection(self: *Server, connection: std.net.Server.Connection) !void {
        defer connection.stream.close();

        var buf: [4096]u8 = undefined;
        const request_size = try connection.stream.read(&buf);
        const request = buf[0..request_size];

        // Parse the request to get the target path
        var lines = std.mem.splitSequence(u8, request, "\r\n");
        const first_line = lines.first();
        var parts = std.mem.splitSequence(u8, first_line, " ");
        _ = parts.first(); // Skip method
        const target = parts.next() orelse return error.InvalidRequest;
        const target_dup = try self.allocator.dupe(u8, target);
        defer self.allocator.free(target_dup);

        // Handle clean URLs
        const path = if (std.mem.eql(u8, target_dup, "/")) "public/index.html" else blk: {
            // If the path ends with /, append index.html
            if (std.mem.endsWith(u8, target_dup, "/")) {
                break :blk try std.fmt.allocPrint(
                    self.allocator,
                    "public{s}index.html",
                    .{target_dup},
                );
            } else {
                // Otherwise, try to serve the file directly
                break :blk try std.fmt.allocPrint(
                    self.allocator,
                    "public{s}",
                    .{target_dup},
                );
            }
        };
        defer if (!std.mem.eql(u8, path, "public/index.html")) self.allocator.free(path);

        // Try to open and read the file
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                try self.send404Response(connection);
                return;
            }
            return err;
        };
        defer file.close();

        // Send HTTP response headers with content type
        const content_type = self.getContentType(path);
        try connection.stream.writer().print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\n\r\n", .{content_type});

        // Send file contents
        var buffer: [8192]u8 = undefined;
        while (true) {
            const size = try file.read(&buffer);
            if (size == 0) break;
            _ = try connection.stream.write(buffer[0..size]);
        }
    }

    fn getContentType(self: *Server, path: []const u8) []const u8 {
        _ = self;
        if (std.mem.endsWith(u8, path, ".html")) return "text/html";
        if (std.mem.endsWith(u8, path, ".css")) return "text/css";
        if (std.mem.endsWith(u8, path, ".js")) return "text/javascript";
        if (std.mem.endsWith(u8, path, ".png")) return "image/png";
        if (std.mem.endsWith(u8, path, ".jpg") or std.mem.endsWith(u8, path, ".jpeg")) return "image/jpeg";
        return "text/plain";
    }

    fn send404Response(self: *Server, connection: std.net.Server.Connection) !void {
        _ = self;
        const response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found";
        _ = try connection.stream.write(response);
    }
};

pub fn serve(allocator: Allocator, port: u16) !void {
    std.debug.print("\n=== Server Initialization ===\n", .{});
    var server_instance = try Server.init(allocator, port);
    std.debug.print("Server instance created\n", .{});
    defer server_instance.deinit();

    // Add error handling for the start method
    server_instance.start() catch |err| {
        std.log.err("Server error: {}", .{err});
        return err;
    };
}
