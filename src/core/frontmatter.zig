const std = @import("std");
const Frontmatter = @import("types.zig").Frontmatter;

/// Parse frontmatter from markdown content
/// The returned Frontmatter struct contains allocated strings that the caller
/// takes ownership of and must free.
pub fn parseFrontmatter(allocator: std.mem.Allocator, content: []const u8) !Frontmatter {

    // Check if content starts with frontmatter delimiter
    if (!std.mem.startsWith(u8, content, "---\n")) {
        std.log.err("No frontmatter delimiter found: {s}", .{"error"});
        return error.InvalidFrontmatter;
    }

    // Find end of frontmatter
    const end_marker = "\n---\n";
    const frontmatter_end = std.mem.indexOf(u8, content[4..], end_marker) orelse {
        std.log.err("No end delimiter found: {s}", .{"error"});
        return error.InvalidFrontmatter;
    };

    // Extract frontmatter content
    const frontmatter_content = content[4..][0..frontmatter_end];

    var title: []const u8 = "";
    var date: []const u8 = "";
    var title_owned = false;
    var date_owned = false;

    // We'll use this to free memory on error
    errdefer {
        if (title_owned and title.len > 0) allocator.free(title);
        if (date_owned and date.len > 0) allocator.free(date);
    }

    // Parse line by line
    var lines = std.mem.splitSequence(u8, frontmatter_content, "\n");
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "title:")) |i| {
            // Free any previous allocation if we had one
            if (title_owned and title.len > 0) {
                allocator.free(title);
            }

            const value = std.mem.trim(u8, line[i + 6 ..], " ");
            // Handle quoted values
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                title = try allocator.dupe(u8, value[1 .. value.len - 1]);
            } else {
                title = try allocator.dupe(u8, value);
            }
            title_owned = true;
        } else if (std.mem.indexOf(u8, line, "date:")) |i| {
            // Free any previous allocation if we had one
            if (date_owned and date.len > 0) {
                allocator.free(date);
            }

            const value = std.mem.trim(u8, line[i + 5 ..], " ");
            // Handle quoted values
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                date = try allocator.dupe(u8, value[1 .. value.len - 1]);
            } else {
                date = try allocator.dupe(u8, value);
            }
            date_owned = true;
        }
    }

    if (title.len == 0 or date.len == 0) {
        std.log.err("Missing required fields: {s}", .{"error"});
        return error.MissingRequiredFields;
    }

    return Frontmatter{
        .title = title,
        .date = date,
    };
}
