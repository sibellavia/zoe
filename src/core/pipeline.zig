const std = @import("std");
const config = @import("config.zig");
const fs = @import("../utils/fs.zig");
const template = @import("template.zig");
const url = @import("../utils/url.zig");
const sitemap = @import("../utils/sitemap.zig");
const types = @import("types.zig");
const ContentProcessor = @import("content.zig").ContentProcessor;

/// Pipeline steps enumeration - define all possible pipeline steps
const PipelineStepKind = enum {
    setup_directories,
    process_content,
    apply_templates,
    write_output,
    generate_sitemap,
};

/// Pipeline step struct - contains the step kind and function pointer
const Step = struct {
    kind: PipelineStepKind,
    name: []const u8,
    run: *const fn (context: *BuildContext) anyerror!void,
};

/// Build context - contains all data needed for the pipeline to run
const BuildContext = struct {
    allocator: std.mem.Allocator,
    config: config.SiteConfig,
    content_processor: *ContentProcessor,
    template_manager: ?*template.TemplateManager = null,
};

/// Main pipeline struct
pub const Pipeline = struct {
    context: BuildContext,
    steps: []const Step,

    /// Initialize a new pipeline with the given allocator and site config
    pub fn init(allocator: std.mem.Allocator, site_config: config.SiteConfig) !Pipeline {
        const content_processor = ContentProcessor.init(allocator) catch |err| {
            std.log.err("Failed to initialize content processor: {s}", .{@errorName(err)});
            return err;
        };
        errdefer content_processor.deinit();

        return .{
            .context = BuildContext{
                .allocator = allocator,
                .config = site_config,
                .content_processor = content_processor,
            },
            .steps = &[_]Step{
                .{
                    .kind = .setup_directories,
                    .name = "Setup Directories",
                    .run = setupDirectories,
                },
                .{
                    .kind = .process_content,
                    .name = "Process Content",
                    .run = processContent,
                },
                .{
                    .kind = .apply_templates,
                    .name = "Apply Templates",
                    .run = applyTemplates,
                },
                .{
                    .kind = .write_output,
                    .name = "Write Output",
                    .run = writeOutput,
                },
                .{
                    .kind = .generate_sitemap,
                    .name = "Generate Sitemap",
                    .run = generateSitemap,
                },
            },
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Pipeline) void {
        // Content processor owns its own memory and cleans up in its deinit method
        self.context.content_processor.deinit();

        // Free template manager if it exists
        if (self.context.template_manager) |tm| {
            tm.deinit();
        }
    }

    /// Run the pipeline with all steps
    pub fn run(self: *Pipeline) !void {
        for (self.steps) |step| {
            std.debug.print("Running step: {s}\n", .{step.name});
            step.run(&self.context) catch |err| {
                std.log.err("Step '{s}' failed: {s}", .{ step.name, @errorName(err) });
                return err;
            };
        }
        std.debug.print("Template application complete\n", .{});
    }

    /// Setup directories for the build
    fn setupDirectories(context: *BuildContext) !void {
        const assets_dir = context.config.getAssetsDir() orelse "static";

        // Use the consolidated setupDirectories function from fs.zig
        try fs.setupDirectories(fs.SetupDirectoriesOptions{
            .allocator = context.allocator,
            .input_dir = config.SiteConfig.getContentDir(),
            .output_dir = context.config.getOutputDir(),
            .assets_dir = assets_dir,
        });
    }

    /// Process content from the input directory
    fn processContent(context: *BuildContext) !void {
        context.content_processor.processContent(config.SiteConfig.getContentDir()) catch |err| {
            std.log.err("Content processing failed: {any}", .{@errorName(err)});
            return err;
        };
    }

    /// Apply templates to all content
    fn applyTemplates(context: *BuildContext) !void {
        const templates_dir = config.SiteConfig.getTemplatesDir();
        const template_path = try std.fmt.allocPrint(context.allocator, "{s}/base.html", .{templates_dir});
        defer context.allocator.free(template_path);

        // Check if the template file exists
        if (!fs.fileExists(template_path)) {
            std.log.err("Required template '{s}' not found in templates directory", .{"base.html"});
            return error.RequiredTemplateNotFound;
        }

        var tm = template.TemplateManager.init(
            context.allocator,
            context.content_processor.arena.allocator(),
            config.SiteConfig.getTemplatesDir(),
        ) catch |err| {
            std.log.err("Failed to initialize template manager: {s}", .{@errorName(err)});
            return err;
        };
        context.template_manager = tm;

        tm.setConfig(context.config);

        template.applyTemplates(context.content_processor, tm) catch |err| {
            std.log.err("Template application failed: {s}", .{@errorName(err)});
            return err;
        };

        std.debug.print("Template application complete\n", .{});
    }

    /// Write processed content to output directory
    fn writeOutput(context: *BuildContext) !void {
        fs.WriteOutput(fs.WriteOutputOptions{
            .allocator = context.allocator,
            .collection = context.content_processor,
            .input_dir = config.SiteConfig.getContentDir(),
            .output_dir = context.config.getOutputDir(),
            .base_url = context.config.base_url,
        }) catch |err| {
            std.log.err("Failed to write output: {s}", .{@errorName(err)});
            return err;
        };

        std.log.debug("Output writing complete", .{});
    }

    /// Generate sitemap for the site
    fn generateSitemap(context: *BuildContext) !void {
        var sg = sitemap.SitemapGenerator.init(context.allocator, context.config.base_url) catch |err| {
            std.log.err("Failed to initialize sitemap generator: {s}", .{@errorName(err)});
            return err;
        };
        defer sg.deinit();

        const all_content = context.content_processor.getAllContent() catch |err| {
            std.log.err("Failed to get content for sitemap: {s}", .{@errorName(err)});
            return err;
        };

        for (all_content) |content_item| {
            sg.addPage(content_item) catch |err| {
                std.log.err("Failed to add page to sitemap: {s}", .{@errorName(err)});
                return err;
            };
        }

        sg.writeSitemap(context.config.getOutputDir()) catch |err| {
            std.log.err("Failed to write sitemap: {s}", .{@errorName(err)});
            return err;
        };

        std.log.debug("Sitemap generation complete", .{});
    }
};
