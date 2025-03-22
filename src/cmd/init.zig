const std = @import("std");

const CommandOptions = struct {
    site_name: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
};

/// Initialize a new Zoe project with default templates and configuration
pub fn execute(options: CommandOptions) !void {
    const site_name = options.site_name orelse "my-zoe-site";
    std.debug.print("Initializing new Zoe project: {s}\n", .{site_name});

    // Create the zoe-website directory first
    try std.fs.cwd().makeDir("zoe-website");

    // Create project directory structure
    const required_dirs = [_][]const u8{
        "zoe-website/content",
        "zoe-website/content/posts",
        "zoe-website/templates",
        "zoe-website/static",
        "zoe-website/static/css",
        "zoe-website/static/images",
    };

    for (required_dirs) |dir| {
        try std.fs.cwd().makePath(dir);
    }

    // Create default zoe-config.json
    try createConfigFile(site_name, options.base_url orelse "http://localhost:8080");

    // Create example content files
    try createContentFiles();

    // Create templates
    try createTemplateFiles();

    // Create static files
    try createStaticFiles();

    // Create .gitignore
    try createGitignore();

    std.debug.print("Successfully initialized Zoe project in zoe-website/\n", .{});
    std.debug.print("Get started by cd'ing into zoe-website/ and running 'zoe serve'\n", .{});
}

fn createConfigFile(site_name: []const u8, base_url: []const u8) !void {
    const config_file = try std.fs.cwd().createFile("zoe-website/zoe-config.json", .{});
    defer config_file.close();
    const writer = config_file.writer();

    try writer.writeAll("{\n");
    try std.fmt.format(writer,
        \\  "site": {{
        \\    "title": "{s}",
        \\    "description": "A site built with Zoe",
        \\    "base_url": "{s}"
        \\  }},
        \\  "build": {{
        \\    "output_dir": "public",
        \\    "assets_dir": "static"
        \\  }},
        \\  "seo": {{
        \\    "twitter_handle": "",
        \\    "twitter_card_type": "summary_large_image",
        \\    "default_image": "/static/images/default-banner.jpg",
        \\    "favicon": "/static/images/favicon.ico",
        \\    "google_analytics": "",
        \\    "enable_sitemap": true,
        \\    "author": "Your Name",
        \\    "keywords": "blog, technology, programming, zig"
        \\  }},
        \\  "github_pages": {{
        \\    "branch": "gh-pages",
        \\    "cname": ""
        \\  }}
        \\}}
        \\
    , .{ site_name, base_url });
}

fn createContentFiles() !void {
    // Create example content - index.md (homepage)
    {
        const example_md = try std.fs.cwd().createFile("zoe-website/content/index.md", .{});
        defer example_md.close();
        const writer = example_md.writer();

        try writer.writeAll(
            \\---
            \\title: "Welcome to Zoe"
            \\date: "2025-02-23"
            \\---
            \\
            \\## Welcome to Your New Zoe Site
            \\
            \\This is your homepage. You can edit this content in `content/index.md`.
            \\
            \\## Quick Start
            \\
            \\1. Edit the site configuration in `zoe-config.json`
            \\2. Add your content to the `content/` directory
            \\3. Customize your templates in `templates/`
            \\4. Add static assets to `static/`
            \\5. Run `zoe serve` to start the development server
            \\6. Run `zoe build` when you're ready to deploy
            \\
        );
    }

    // Create an example blog post
    {
        const post_md = try std.fs.cwd().createFile("zoe-website/content/posts/first-post.md", .{});
        defer post_md.close();
        const writer = post_md.writer();

        try writer.writeAll(
            \\---
            \\title: "My First Blog Post"
            \\date: "2025-02-23"
            \\---
            \\
            \\This is an example blog post. You can edit this file at `content/posts/first-post.md` or create new blog posts in the `content/posts/` directory.
            \\
            \\## Using Markdown
            \\
            \\Zoe supports standard Markdown syntax:
            \\
            \\- **Bold text** and *italic text*
            \\- [Links](https://example.com)
            \\- Lists and code blocks
            \\
            \\### Code Example
            \\
            \\```zig
            \\const std = @import("std");
            \\
            \\pub fn main() !void {
            \\    std.debug.print("Hello, Zoe!\n", .{});
            \\}
            \\```
            \\
            \\### LaTeX Support
            \\
            \\Zoe supports LaTeX equations:
            \\
            \\$$
            \\f(x) = \int_{-\infty}^{\infty} \hat{f}(\xi) e^{2\pi i \xi x} d\xi
            \\$$
            \\
        );
    }

    // Create an _index.md file for the posts section
    {
        const posts_index = try std.fs.cwd().createFile("zoe-website/content/posts/_index.md", .{});
        defer posts_index.close();
        const writer = posts_index.writer();

        try writer.writeAll(
            \\---
            \\title: "Blog Posts"
            \\date: "2025-02-23"
            \\---
            \\
            \\This is your blog index page. It will be displayed when visiting `/posts/`.
            \\
            \\All posts in the posts directory will be automatically listed below thanks to the 
            \\list template and the `{{#each pages}}` construct.
            \\
            \\Feel free to add an introduction to your blog here.
            \\
        );
    }

    // Create a section with _index.md
    try std.fs.cwd().makePath("zoe-website/content/docs");
    {
        const section_index = try std.fs.cwd().createFile("zoe-website/content/docs/_index.md", .{});
        defer section_index.close();
        const writer = section_index.writer();

        try writer.writeAll(
            \\---
            \\title: "Documentation"
            \\date: "2025-02-23"
            \\---
            \\
            \\This is an example section index page. This page will be displayed when visiting `/docs/`.
            \\
            \\Sections can contain their own index pages and regular content pages. They are automatically listed when using the list.html template.
            \\
        );
    }

    // Create an example page in the docs section
    {
        const doc_page = try std.fs.cwd().createFile("zoe-website/content/docs/getting-started.md", .{});
        defer doc_page.close();
        const writer = doc_page.writer();

        try writer.writeAll(
            \\---
            \\title: "Getting Started"
            \\date: "2025-02-23"
            \\---
            \\
            \\## Getting Started with Zoe
            \\
            \\This is an example documentation page in the docs section.
            \\
            \\## Installation
            \\
            \\Zoe can be installed by cloning the repository and building from source.
            \\
            \\```bash
            \\git clone https://github.com/username/zoe.git
            \\cd zoe
            \\zig build
            \\```
            \\
        );
    }
}

fn createTemplateFiles() !void {
    // Create default base template
    {
        const template_file = try std.fs.cwd().createFile("zoe-website/templates/base.html", .{});
        defer template_file.close();
        const writer = template_file.writer();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\    
            \\    <!-- Basic SEO -->
            \\    <title>{title}</title>
            \\    <meta name="description" content="{description|site.description}">
            \\    <meta name="keywords" content="{keywords|site.seo.keywords}">
            \\    <meta name="author" content="{author|site.seo.author}">
            \\    
            \\    <!-- Favicon -->
            \\    <link rel="icon" type="image/x-icon" href="{site.seo.favicon}">
            \\    <link rel="shortcut icon" type="image/x-icon" href="{site.seo.favicon}">
            \\
            \\    <!-- Open Graph / Facebook -->
            \\    <meta property="og:type" content="{og_type|article}">
            \\    <meta property="og:url" content="{site.base_url}{current_url}">
            \\    <meta property="og:title" content="{title}">
            \\    <meta property="og:description" content="{description|site.description}">
            \\    <meta property="og:image" content="{site.base_url}{banner_image|site.seo.default_image}">
            \\
            \\    <!-- Twitter -->
            \\    <meta name="twitter:card" content="{site.seo.twitter_card_type}">
            \\    <meta name="twitter:site" content="{site.seo.twitter_handle}">
            \\    <meta name="twitter:title" content="{title}">
            \\    <meta name="twitter:description" content="{description|site.description}">
            \\    <meta name="twitter:image" content="{site.base_url}{banner_image|site.seo.default_image}">
            \\
            \\    <link rel="stylesheet" href="/static/css/style.css">
            \\    <!-- Add MathJax for LaTeX rendering -->
            \\    <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            \\    <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            \\    <!-- Add Prism.js for code highlighting -->
            \\    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism.min.css">
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"></script>
            \\    <!-- Add languages you want to support (or use the autoloader) -->
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-zig.min.js"></script>
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-bash.min.js"></script>
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-javascript.min.js"></script>
            \\</head>
            \\<body>
            \\    <header>
            \\        <nav>
            \\            <a href="/">Home</a>
            \\            <a href="/posts/">Blog</a>
            \\            <a href="/docs/">Docs</a>
            \\        </nav>
            \\    </header>
            \\    <main>
            \\        <article>
            \\            <h1>{title}</h1>
            \\            {content}
            \\        </article>
            \\    </main>
            \\    <footer>
            \\        <p>Built with <a href="https://github.com/username/zoe">Zoe</a></p>
            \\    </footer>
            \\</body>
            \\</html>
            \\
        );
    }

    // Create list template for sections
    {
        const list_template = try std.fs.cwd().createFile("zoe-website/templates/list.html", .{});
        defer list_template.close();
        const writer = list_template.writer();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\    
            \\    <!-- Basic SEO -->
            \\    <title>{{title}}</title>
            \\    <meta name="description" content="{{description|site.description}}">
            \\    <meta name="keywords" content="{{keywords|site.seo.keywords}}">
            \\    <meta name="author" content="{{author|site.seo.author}}">
            \\    
            \\    <!-- Favicon -->
            \\    <link rel="icon" type="image/x-icon" href="{{site.seo.favicon}}">
            \\    <link rel="shortcut icon" type="image/x-icon" href="{{site.seo.favicon}}">
            \\
            \\    <!-- Open Graph / Facebook -->
            \\    <meta property="og:type" content="website">
            \\    <meta property="og:url" content="{{site.base_url}}{{current_url}}">
            \\    <meta property="og:title" content="{{title}}">
            \\    <meta property="og:description" content="{{description|site.description}}">
            \\    <meta property="og:image" content="{{site.base_url}}{{banner_image|site.seo.default_image}}">
            \\
            \\    <!-- Twitter -->
            \\    <meta name="twitter:card" content="{{site.seo.twitter_card_type}}">
            \\    <meta name="twitter:site" content="{{site.seo.twitter_handle}}">
            \\    <meta name="twitter:title" content="{{title}}">
            \\    <meta name="twitter:description" content="{{description|site.description}}">
            \\    <meta name="twitter:image" content="{{site.base_url}}{{banner_image|site.seo.default_image}}">
            \\
            \\    <link rel="stylesheet" href="/static/css/style.css">
            \\</head>
            \\<body>
            \\    <header>
            \\        <nav>
            \\            <a href="/">Home</a>
            \\            <a href="/posts/">Blog</a>
            \\            <a href="/docs/">Docs</a>
            \\        </nav>
            \\    </header>
            \\    <main>
            \\        <article>
            \\            <h1>{{title}}</h1>
            \\            {{content}}
            \\            
            \\            <h2>Contents</h2>
            \\            <ul class="page-list">
            \\                {{#each pages}}
            \\                <li>
            \\                    <a href="{{this.url}}">{{this.title}}</a>
            \\                    <span class="date">{{this.date}}</span>
            \\                </li>
            \\                {{/each}}
            \\            </ul>
            \\        </article>
            \\    </main>
            \\    <footer>
            \\        <p>Built with <a href="https://github.com/username/zoe">Zoe</a></p>
            \\    </footer>
            \\</body>
            \\</html>
            \\
        );
    }

    // Create post template for blog posts
    {
        const post_template = try std.fs.cwd().createFile("zoe-website/templates/post.html", .{});
        defer post_template.close();
        const writer = post_template.writer();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\    
            \\    <!-- Basic SEO -->
            \\    <title>{{title}}</title>
            \\    <meta name="description" content="{{description|site.description}}">
            \\    <meta name="keywords" content="{{keywords|site.seo.keywords}}">
            \\    <meta name="author" content="{{author|site.seo.author}}">
            \\    
            \\    <!-- Favicon -->
            \\    <link rel="icon" type="image/x-icon" href="{{site.seo.favicon}}">
            \\    <link rel="shortcut icon" type="image/x-icon" href="{{site.seo.favicon}}">
            \\
            \\    <!-- Open Graph / Facebook -->
            \\    <meta property="og:type" content="article">
            \\    <meta property="og:url" content="{{site.base_url}}{{current_url}}">
            \\    <meta property="og:title" content="{{title}}">
            \\    <meta property="og:description" content="{{description|site.description}}">
            \\    <meta property="og:image" content="{{site.base_url}}{{banner_image|site.seo.default_image}}">
            \\    {{#if date}}
            \\    <meta property="article:published_time" content="{{date}}">
            \\    {{/if}}
            \\
            \\    <!-- Twitter -->
            \\    <meta name="twitter:card" content="{{site.seo.twitter_card_type}}">
            \\    <meta name="twitter:site" content="{{site.seo.twitter_handle}}">
            \\    <meta name="twitter:title" content="{{title}}">
            \\    <meta name="twitter:description" content="{{description|site.description}}">
            \\    <meta name="twitter:image" content="{{site.base_url}}{{banner_image|site.seo.default_image}}">
            \\
            \\    <link rel="stylesheet" href="/static/css/style.css">
            \\    <!-- Add MathJax for LaTeX rendering -->
            \\    <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            \\    <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            \\    <!-- Add Prism.js for code highlighting -->
            \\    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism.min.css">
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"></script>
            \\    <!-- Add languages you want to support (or use the autoloader) -->
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-zig.min.js"></script>
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-bash.min.js"></script>
            \\    <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-javascript.min.js"></script>
            \\</head>
            \\<body>
            \\    <header>
            \\        <nav>
            \\            <a href="/">Home</a>
            \\            <a href="/posts/">Blog</a>
            \\            <a href="/docs/">Docs</a>
            \\        </nav>
            \\    </header>
            \\    <main>
            \\        <article class="blog-post">
            \\            <header>
            \\                <h1>{{title}}</h1>
            \\                <div class="post-meta">
            \\                    <span class="post-date">{{date}}</span>
            \\                </div>
            \\            </header>
            \\            <div class="post-content">
            \\                {{content}}
            \\            </div>
            \\            <div class="post-footer">
            \\                <a href="/posts/">← Back to all posts</a>
            \\            </div>
            \\        </article>
            \\    </main>
            \\    <footer>
            \\        <p>Built with <a href="https://github.com/username/zoe">Zoe</a></p>
            \\    </footer>
            \\</body>
            \\</html>
            \\
        );
    }
}

fn createStaticFiles() !void {
    // Create basic CSS
    {
        const css_file = try std.fs.cwd().createFile("zoe-website/static/css/style.css", .{});
        defer css_file.close();
        const writer = css_file.writer();

        try writer.writeAll(
            \\/* Basic styles */
            \\:root {
            \\    --primary-color: #4a5568;
            \\    --background-color: #ffffff;
            \\    --text-color: #2d3748;
            \\}
            \\
            \\body {
            \\    font-family: system-ui, -apple-system, sans-serif;
            \\    line-height: 1.6;
            \\    color: var(--text-color);
            \\    max-width: 800px;
            \\    margin: 0 auto;
            \\    padding: 2rem;
            \\}
            \\
            \\a {
            \\    color: var(--primary-color);
            \\    text-decoration: none;
            \\}
            \\
            \\a:hover {
            \\    text-decoration: underline;
            \\}
            \\
            \\header {
            \\    margin-bottom: 2rem;
            \\    padding-bottom: 1rem;
            \\    border-bottom: 1px solid #edf2f7;
            \\}
            \\
            \\nav a {
            \\    margin-right: 1rem;
            \\}
            \\
            \\footer {
            \\    margin-top: 2rem;
            \\    padding-top: 1rem;
            \\    border-top: 1px solid #edf2f7;
            \\    text-align: center;
            \\    font-size: 0.875rem;
            \\    color: var(--primary-color);
            \\}
            \\
            \\/* Post styles */
            \\.post-meta {
            \\    margin-bottom: 2rem;
            \\    color: var(--primary-color);
            \\}
            \\
            \\.post-date {
            \\    font-size: 0.875rem;
            \\}
            \\
            \\.post-footer {
            \\    margin-top: 2rem;
            \\}
            \\
            \\/* List styles */
            \\.page-list {
            \\    list-style-type: none;
            \\    padding: 0;
            \\}
            \\
            \\.page-list li {
            \\    padding: 0.5rem 0;
            \\    border-bottom: 1px solid #edf2f7;
            \\}
            \\
            \\.page-list .date {
            \\    font-size: 0.875rem;
            \\    color: var(--primary-color);
            \\    margin-left: 1rem;
            \\}
            \\
            \\/* Code blocks */
            \\pre {
            \\    background-color: #f7fafc;
            \\    border-radius: 0.25rem;
            \\    padding: 1rem;
            \\    overflow-x: auto;
            \\}
            \\
            \\code {
            \\    font-family: monospace;
            \\}
            \\
        );
    }

    // Create default banner image
    {
        const banner_file = try std.fs.cwd().createFile("zoe-website/static/images/default-banner.svg", .{});
        defer banner_file.close();
        const writer = banner_file.writer();

        try writer.writeAll(
            \\<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
            \\  <rect width="1200" height="630" fill="#4a5568"/>
            \\  <text x="600" y="315" font-family="Arial, sans-serif" font-size="72" text-anchor="middle" fill="white">
            \\    my-zoe-site
            \\  </text>
            \\  <text x="600" y="400" font-family="Arial, sans-serif" font-size="32" text-anchor="middle" fill="#e2e8f0">
            \\    A site built with Zoe
            \\  </text>
            \\</svg>
        );
    }

    // Create default favicon
    {
        const favicon_file = try std.fs.cwd().createFile("zoe-website/static/images/favicon.svg", .{});
        defer favicon_file.close();
        const writer = favicon_file.writer();

        try writer.writeAll(
            \\<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg">
            \\  <rect width="32" height="32" fill="#4a5568" rx="4" ry="4"/>
            \\  <text x="16" y="22" font-family="Arial, sans-serif" font-size="20" font-weight="bold" text-anchor="middle" fill="white">Z</text>
            \\</svg>
        );
    }
}

fn createGitignore() !void {
    const gitignore = try std.fs.cwd().createFile("zoe-website/.gitignore", .{});
    defer gitignore.close();
    const writer = gitignore.writer();

    try writer.writeAll(
        \\public/
        \\*.swp
        \\.DS_Store
        \\
    );
}
