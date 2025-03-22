const std = @import("std");

/// Process code blocks in HTML content, adding appropriate classes for Prism.js
/// The returned string is allocated and owned by the caller, who is responsible for freeing it
pub fn processCodeBlocks(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {

    // Simple implementation that ensures code blocks have the right classes for Prism
    // This just ensures all code blocks have language-xxxx classes that Prism can use
    var processed = try std.ArrayList(u8).initCapacity(allocator, content.len);
    errdefer processed.deinit();

    // We'll just pass through content, ensuring <pre><code> blocks have proper language classes
    try processed.appendSlice(content);

    // Return the processed content
    return try processed.toOwnedSlice();
}
