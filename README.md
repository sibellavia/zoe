# Zoe: A Minimalist Static Site Generator

> **Note:** Zoe is at version 0.0.1 and while functional, it's still under development. The API and features may change significantly before the first stable release. Zoe tracks Zig's version 0.14.0.

Zoe is a lightweight static site generator written in Zig, designed specifically for technical writing and blogging. It converts Markdown files into clean HTML while properly handling technical content like LaTeX equations and code blocks.

## Principles

Zoe is built on three core principles:

1. **Minimalism**: Every feature must justify its existence. Zoe focuses on the essential needs of technical writers and bloggers without unnecessary complexity.

2. **Transparency**: The entire static site generation process should be understandable and predictable. Users can see exactly how their content is transformed.

3. **Technical Focus**: First-class support for LaTeX equations and syntax-highlighted code blocks.

## Quick Start

1. **Building**
   ```bash
   git clone https://github.com/yourusername/zoe.git
   cd zoe
   zig build
   ```

2. **Create a New Site**
   ```bash
   zoe init my-site
   cd my-site
   ```

3. **Add Content**
   Create Markdown files in the `content` directory with your posts or pages.

4. **Generate Site**
   ```bash
   zoe build
   ```

5. **Preview**
   ```bash
   zoe serve
   ```

For detailed documentation, configuration options, and advanced features, please refer to the [comprehensive documentation](docs/DOC.md).

## LICENSE

Zoe is licensed under the MIT license. See the [LICENSE](LICENSE) file for details.