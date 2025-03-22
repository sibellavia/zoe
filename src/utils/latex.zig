const std = @import("std");
const cmark = @import("../bindings/cmark.zig");

/// Process LaTeX delimiters in HTML content, converting them to MathJax compatible markup
/// The returned string is allocated and owned by the caller, who is responsible for freeing it
pub fn processLatex(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    var processed = std.ArrayList(u8).init(allocator);
    errdefer processed.deinit();

    var i: usize = 0;
    while (i < content.len) {
        if (content[i] == '$') {
            // Check if it's a display math block ($$) or inline ($)
            const is_display = (i + 1 < content.len and content[i + 1] == '$');
            const delim_len: usize = if (is_display) 2 else 1;

            // Find the closing delimiter
            var j = i + delim_len;
            var found_closing = false;
            while (j < content.len) : (j += 1) {
                if (content[j] == '$') {
                    if (is_display) {
                        if (j + 1 < content.len and content[j + 1] == '$') {
                            // Found closing $$ for display math
                            const latex = content[i + delim_len .. j];
                            try processed.appendSlice("<div class=\"math display\">\\[");
                            try processed.appendSlice(latex);
                            try processed.appendSlice("\\]</div>");
                            i = j + 2; // Skip both $ characters
                            found_closing = true;
                            break;
                        }
                    } else {
                        // For inline math, ensure this $ isn't part of a $$
                        if (j + 1 >= content.len or content[j + 1] != '$') {
                            const latex = content[i + delim_len .. j];
                            try processed.appendSlice("<span class=\"math inline\">\\(");
                            try processed.appendSlice(latex);
                            try processed.appendSlice("\\)</span>");
                            i = j + 1; // Skip the closing $
                            found_closing = true;
                            break;
                        }
                    }
                }
            }

            if (!found_closing) {
                // If no closing delimiter was found, treat as regular text
                try processed.append(content[i]);
                i += 1;
            }
        } else {
            try processed.append(content[i]);
            i += 1;
        }
    }

    const result = try processed.toOwnedSlice();

    // toOwnedSlice() already frees the ArrayList but keeps the underlying buffer,
    // which will be owned by the caller
    return result;
}
