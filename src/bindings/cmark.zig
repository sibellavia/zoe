const std = @import("std");
const c = @cImport({
    @cInclude("cmark-gfm.h");
    @cInclude("cmark-gfm-core-extensions.h");
});

pub const Error = error{
    OutOfMemory,
    ParseError,
    ExtensionError,
    InvalidUtf8,
};

var extensions_registered = false;

pub const Document = struct {
    node: *c.cmark_node,
    parser: *c.cmark_parser,
    allocator: std.mem.Allocator,

    pub fn init() void {
        if (!extensions_registered) {
            c.cmark_gfm_core_extensions_ensure_registered();
            extensions_registered = true;
        }
    }

    pub fn parse(allocator: std.mem.Allocator, content: []const u8) Error!*Document {
        // Initialize extensions
        Document.init();

        // Validate UTF-8 first
        if (!std.unicode.utf8ValidateSlice(content)) {
            return error.InvalidUtf8;
        }

        // Create parser with GFM extensions
        const parser = c.cmark_parser_new(c.CMARK_OPT_DEFAULT) orelse return error.OutOfMemory;
        errdefer c.cmark_parser_free(parser);

        // Add GFM extensions
        const table_ext = c.cmark_find_syntax_extension("table") orelse return error.ExtensionError;
        if (c.cmark_parser_attach_syntax_extension(parser, table_ext) == 0) return error.ExtensionError;

        const strikethrough_ext = c.cmark_find_syntax_extension("strikethrough") orelse return error.ExtensionError;
        if (c.cmark_parser_attach_syntax_extension(parser, strikethrough_ext) == 0) return error.ExtensionError;

        const autolink_ext = c.cmark_find_syntax_extension("autolink") orelse return error.ExtensionError;
        if (c.cmark_parser_attach_syntax_extension(parser, autolink_ext) == 0) return error.ExtensionError;

        const tasklist_ext = c.cmark_find_syntax_extension("tasklist") orelse return error.ExtensionError;
        if (c.cmark_parser_attach_syntax_extension(parser, tasklist_ext) == 0) return error.ExtensionError;

        // Parse document
        _ = c.cmark_parser_feed(parser, content.ptr, content.len);
        const node = c.cmark_parser_finish(parser) orelse {
            c.cmark_parser_free(parser);
            return error.ParseError;
        };
        errdefer c.cmark_node_free(node);

        const doc = try allocator.create(Document);
        errdefer allocator.destroy(doc);

        doc.* = .{
            .node = node,
            .parser = parser,
            .allocator = allocator,
        };
        return doc;
    }

    pub fn deinit(self: *Document) void {
        c.cmark_node_free(self.node);
        c.cmark_parser_free(self.parser);
        self.allocator.destroy(self);
    }

    pub fn renderHtml(self: *Document, allocator: std.mem.Allocator) Error![]u8 {
        const c_str = c.cmark_render_html(
            self.node,
            c.CMARK_OPT_DEFAULT | c.CMARK_OPT_UNSAFE,
            null,
        ) orelse return error.OutOfMemory;
        defer std.c.free(c_str);

        const len = std.mem.len(c_str);
        const html = try allocator.alloc(u8, len);
        errdefer allocator.free(html);
        @memcpy(html, c_str[0..len]);
        return html;
    }
};
