# Building Websites with Zoe

Zoe is a lightweight static site generator written in Zig, designed specifically for technical writing and blogging. It converts Markdown files into clean HTML while properly handling technical content like LaTeX equations and code blocks.

## Table of Contents

1. [Introduction](#introduction)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Getting Started](#getting-started)
5. [Site Structure](#site-structure)
6. [Content Creation](#content-creation)
7. [Customization](#customization)
8. [Building and Deployment](#building-and-deployment)
9. [Advanced Usage](#advanced-usage)

## Introduction

Zoe follows three core principles:

1. **Minimalism**: Every feature must justify its existence. Zoe focuses on the essential needs of technical writers and bloggers without unnecessary complexity.

2. **Transparency**: The entire static site generation process is understandable and predictable. Users can see exactly how their content is transformed.

3. **Technical Focus**: First-class support for LaTeX equations and syntax-highlighted code blocks.

## Requirements

To build websites with Zoe, you need:

- **Zig 0.14.0**: Zoe is built with Zig and requires version 0.14.0 or later

## Installation

Currently, Zoe is in alpha stage (version 0.0.0-alpha.8). You can install it by:

1. Cloning the repository:
   ```
   git clone https://github.com/your-username/zoe.git
   cd zoe
   ```

2. Building from source:
   ```
   zig build -Doptimize=ReleaseSafe
   ```

3. Adding the binary to your PATH:
   ```
   export PATH=$PATH:/path/to/zoe/zig-out/bin
   ```

## Getting Started

To create a new Zoe website:

1. Initialize a new project:
   ```
   zoe init
   ```
   This creates a new directory called `zoe-website` with all the necessary files and folders.

2. Optionally, you can specify a site name:
   ```
   zoe init --name "My Awesome Site"
   ```

3. Navigate to your new project:
   ```
   cd zoe-website
   ```

4. Run the development server:
   ```
   zoe serve
   ```
   This starts a local server at http://localhost:8080 where you can preview your site.

## Site Structure

A typical Zoe site has the following structure:

```
zoe-website/
├── content/               # Where your Markdown content lives
│   ├── index.md           # Home page
│   └── posts/             # Blog posts directory
│       ├── _index.md      # Posts listing page
│       └── my-post.md     # Individual post
├── templates/             # HTML templates
│   ├── base.html          # Base template
│   ├── list.html          # List template (for directories)
│   └── post.html          # Post template (for individual pages)
├── static/                # Static assets
│   ├── css/               # CSS files
│   └── images/            # Image files
└── zoe-config.json        # Site configuration
```

## Content Creation

### Front Matter

Each content file starts with front matter in YAML format, enclosed by triple dashes:

```markdown
---
title: "My Blog Post"
date: "2025-02-23"
---

Content goes here...
```

### Creating Pages

To create a new page, add a Markdown file to the `content` directory:

```markdown
---
title: "About Me"
date: "2025-02-23"
---

## About Me

This is my about page.
```

Save this as `content/about.md` and it will be accessible at `/about.html`.

### Creating Blog Posts

To create a blog post, add a Markdown file to the `content/posts` directory:

```markdown
---
title: "My Technical Blog Post"
date: "2025-02-23"
---

## Introduction

This is a blog post with technical content.

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
```

Save this as `content/posts/my-technical-post.md`.

## Customization

### Site Configuration

The `zoe-config.json` file controls your site's configuration:

```json
{
  "site": {
    "title": "my-zoe-site",
    "description": "A site built with Zoe",
    "base_url": "http://localhost:8080"
  },
  "build": {
    "output_dir": "public",
    "assets_dir": "static"
  },
  "seo": {
    "twitter_handle": "",
    "twitter_card_type": "summary_large_image",
    "default_image": "/static/images/default-banner.jpg",
    "favicon": "/static/images/favicon.ico",
    "google_analytics": "",
    "enable_sitemap": true,
    "author": "Your Name",
    "keywords": "blog, technology, programming, zig"
  },
  "github_pages": {
    "branch": "gh-pages",
    "cname": ""
  }
}
```

### Modifying Templates

Zoe uses a simple HTML templating system. The three core templates are:

1. **base.html**: The base layout for all pages
2. **list.html**: Used for directory listings (like blog indexes)
3. **post.html**: Used for individual content pages

You can modify these templates to customize the look and feel of your site.

## Building and Deployment

### Building Your Site

To build your site for production:

```
zoe build
```

This generates all static files in the `public` directory (or whatever you've set in your configuration).

### Deploying Your Site

Since Zoe generates static files, you can deploy to any static hosting service:

1. **GitHub Pages**:
   - Configure your GitHub Pages settings in `zoe-config.json`
   - Build your site with `zoe build`
   - Push the `public` directory to your GitHub Pages branch

2. **Netlify, Vercel, etc.**:
   - Connect your repository to the service
   - Set the build command to `zoe build`
   - Set the publish directory to `public`

3. **Traditional web hosting**:
   - Build your site with `zoe build`
   - Upload the contents of the `public` directory to your web server

## Advanced Usage

### Command Line Arguments

Zoe supports essential commands and options:

- `zoe init`: Create a new Zoe site
  - `--name, -n`: Specify site name
  - `--base-url`: Specify base URL

- `zoe serve`: Start development server
  - `--port, -p`: Specify port (default: 8080)

- `zoe build`: Build site for production
  - `--name, -n`: Override site name
  - `--base-url`: Override base URL

- `zoe clean`: Clean build artifacts

- `zoe --version`: Show version
- `zoe --help`: Show help