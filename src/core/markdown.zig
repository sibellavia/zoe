const std = @import("std");
const types = @import("types.zig");
const Content = types.Content;
const cmark = @import("../bindings/cmark.zig");
const frontmatter_parser = @import("frontmatter.zig");
const latex = @import("../utils/latex.zig");
const code_highlighting = @import("../utils/code_highlighting.zig");

// Define specific markdown errors
pub const MarkdownError = error{
    FileNotFound,
    FileReadError,
    InvalidFrontmatter,
    ParseError,
    RenderError,
    LatexProcessingError,
    CodeHighlightingError,
    OutOfMemory,
};

/// Creates a Content struct from a markdown file
pub fn createContentFromMarkdown(allocator: std.mem.Allocator, path: []const u8) MarkdownError!Content {
    // Open and read file
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.log.err("Markdown file not found: {s}", .{path});
                return MarkdownError.FileNotFound;
            },
            error.AccessDenied => {
                std.log.err("Access denied reading markdown file: {s}", .{path});
                return MarkdownError.FileReadError;
            },
            else => {
                std.log.err("Error reading markdown file {s}: {s}", .{ path, @errorName(err) });
                return MarkdownError.FileReadError;
            },
        }
    };
    defer file.close();

    // Read file content
    const file_content = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        std.log.err("Failed to read markdown file content: {s}", .{@errorName(err)});
        return switch (err) {
            error.OutOfMemory => MarkdownError.OutOfMemory,
            else => MarkdownError.FileReadError,
        };
    };
    defer allocator.free(file_content);

    // Parse frontmatter
    const frontmatter = frontmatter_parser.parseFrontmatter(allocator, file_content) catch |err| {
        std.log.err("Failed to parse frontmatter: {s}", .{@errorName(err)});
        return MarkdownError.InvalidFrontmatter;
    };
    errdefer {
        allocator.free(frontmatter.title);
        allocator.free(frontmatter.date);
    }

    // Find markdown content start
    const end_marker = "\n---\n";
    const frontmatter_end = std.mem.indexOf(u8, file_content[4..], end_marker) orelse {
        std.log.err("Invalid frontmatter format in file: {s}", .{path});
        return MarkdownError.InvalidFrontmatter;
    };

    const markdown_content = file_content[4 + frontmatter_end + end_marker.len ..];

    // Parse and render markdown
    const doc = cmark.Document.parse(allocator, markdown_content) catch |err| {
        std.log.err("Failed to parse markdown: {s}", .{@errorName(err)});
        return MarkdownError.ParseError;
    };
    defer doc.deinit();

    const html = doc.renderHtml(allocator) catch |err| {
        std.log.err("Failed to render HTML: {s}", .{@errorName(err)});
        return MarkdownError.RenderError;
    };
    defer allocator.free(html);

    // Process LaTeX
    const processed_with_latex = latex.processLatex(allocator, html) catch |err| {
        std.log.err("Failed to process LaTeX: {s}", .{@errorName(err)});
        return MarkdownError.LatexProcessingError;
    };
    defer allocator.free(processed_with_latex);

    // Process code blocks
    const processed_content = code_highlighting.processCodeBlocks(allocator, processed_with_latex) catch |err| {
        std.log.err("Failed to process code blocks: {s}", .{@errorName(err)});
        return MarkdownError.CodeHighlightingError;
    };
    errdefer allocator.free(processed_content);

    // Get filename and create paths
    const filename = std.fs.path.basename(path);

    const output_path = allocator.dupe(u8, path) catch |err| {
        std.log.err("Failed to allocate output path: {s}", .{@errorName(err)});
        return MarkdownError.OutOfMemory;
    };
    errdefer allocator.free(output_path);

    const url = allocator.dupe(u8, path) catch |err| {
        std.log.err("Failed to allocate URL: {s}", .{@errorName(err)});
        return MarkdownError.OutOfMemory;
    };
    errdefer allocator.free(url);

    const filename_copy = allocator.dupe(u8, filename) catch |err| {
        std.log.err("Failed to allocate filename: {s}", .{@errorName(err)});
        return MarkdownError.OutOfMemory;
    };

    std.debug.print("Creating content from markdown file: {s}\n", .{path});

    return Content{
        .title = frontmatter.title,
        .date = frontmatter.date,
        .content = processed_content,
        .output_path = output_path,
        .url = url,
        .content_type = .page,
        .section_path = null,
        .filename = filename_copy,
    };
}
