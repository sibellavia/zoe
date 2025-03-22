const std = @import("std");

/// Display version information
pub fn showVersion(version: []const u8) void {
    std.debug.print("Zoe version {s}\n", .{version});
}

/// Show help information
pub fn showHelp(version: []const u8) void {
    std.debug.print(
        \\
        \\Zoe, version {s}
        \\A simple, minimalistic static site generator written in Zig.
        \\
        \\Getting Started:
        \\  1. Create a new site:    zoe init --name "My Site"
        \\  2. Start development:    zoe serve
        \\  3. Build for production: zoe build
        \\
        \\Commands:
        \\  init          Initialize a new Zoe project
        \\  build         Build the site for production
        \\  serve         Start development server
        \\  clean         Remove build artifacts
        \\  help          Show this help
        \\  --version     Show version
        \\
        \\Options:
        \\  -v, --verbose     Enable verbose logging
        \\  -p, --port        Set server port (default: 8080)
        \\  -n, --name        Site name for initialization
        \\  --base-url        Override base URL
        \\
        \\Examples:
        \\  # Create a new site
        \\  zoe init --name "My Blog"
        \\
        \\  # Start development server on custom port
        \\  zoe serve --port 3000
        \\
        \\  # Build with custom base URL
        \\  zoe build --base-url https://example.com
        \\
        \\Documentation: https://github.com/sibellavia/zoe#readme
        \\
    , .{version});
}
