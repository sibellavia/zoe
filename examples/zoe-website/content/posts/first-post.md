---
title: "My First Blog Post"
date: "2025-02-23"
---

This is an example blog post. You can edit this file at `content/posts/first-post.md` or create new blog posts in the `content/posts/` directory.

## Using Markdown

Zoe supports standard Markdown syntax:

- **Bold text** and *italic text*
- [Links](https://example.com)
- Lists and code blocks

### Code Example

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, Zoe!\n", .{});
}
```

### LaTeX Support

Zoe supports LaTeX equations:

$$
f(x) = \int_{-\infty}^{\infty} \hat{f}(\xi) e^{2\pi i \xi x} d\xi
$$
