const std = @import("std");
const testing = std.testing;
const cmark = @import("cmark.zig");

test "empty markdown" {
    const allocator = testing.allocator;
    const markdown = "";

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(html.len > 0);
}

test "basic markdown elements" {
    const allocator = testing.allocator;
    const markdown =
        \\# Header
        \\
        \\Regular paragraph with **bold** and *italic* text.
        \\
        \\* List item 1
        \\* List item 2
        \\
        \\1. Numbered item
        \\2. Another item
        \\
        \\> Blockquote
        \\
        \\`inline code`
        \\
        \\```
        \\code block
        \\```
        \\
        \\[Link](https://example.com)
    ;

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<h1>Header</h1>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<strong>bold</strong>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<em>italic</em>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<ul>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<ol>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<blockquote>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<code>inline code</code>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<pre><code>code block") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<a href=\"https://example.com\">") != null);
}

test "GFM table extension" {
    const allocator = testing.allocator;
    const markdown =
        \\| Header 1 | Header 2 |
        \\|----------|----------|
        \\| Cell 1   | Cell 2   |
    ;

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<table>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<th>Header 1</th>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<td>Cell 1</td>") != null);
}

test "GFM strikethrough extension" {
    const allocator = testing.allocator;
    const markdown = "This is ~~struck through~~ text.";

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<del>struck through</del>") != null);
}

test "GFM autolink extension" {
    const allocator = testing.allocator;
    const markdown = "Visit https://example.com for more info.";

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<a href=\"https://example.com\">") != null);
}

test "GFM task list extension" {
    const allocator = testing.allocator;
    const markdown =
        \\- [ ] Unchecked task
        \\- [x] Checked task
    ;

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "type=\"checkbox\"") != null);
    try testing.expect(std.mem.indexOf(u8, html, "checked") != null);
}

test "invalid UTF-8" {
    const allocator = testing.allocator;
    const markdown = "Hello \xFF World"; // Invalid UTF-8 byte

    const result = cmark.Document.parse(allocator, markdown);
    try testing.expectError(error.InvalidUtf8, result);
}

test "nested markdown structures" {
    const allocator = testing.allocator;
    const markdown =
        \\# Main Header
        \\
        \\> This is a blockquote
        \\> * With a list
        \\> * And **bold** text
        \\>
        \\> ```
        \\> And some code
        \\> ```
    ;

    var doc = try cmark.Document.parse(allocator, markdown);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<blockquote>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<ul>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<strong>bold</strong>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<pre><code>And some code") != null);
}

test "large markdown document" {
    const allocator = testing.allocator;
    var markdown = std.ArrayList(u8).init(allocator);
    defer markdown.deinit();

    // Create a large markdown document
    for (0..100) |i| {
        try markdown.appendSlice("# Header ");
        var buf: [10]u8 = undefined;
        const num = try std.fmt.bufPrint(&buf, "{d}", .{i});
        try markdown.appendSlice(num);
        try markdown.appendSlice("\n\nParagraph with **bold** text.\n\n");
    }

    var doc = try cmark.Document.parse(allocator, markdown.items);
    defer doc.deinit();

    const html = try doc.renderHtml(allocator);
    defer allocator.free(html);

    try testing.expect(html.len > markdown.items.len);
    try testing.expect(std.mem.count(u8, html, "<h1>") == 100);
}
