const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const header_install_dir = b.getInstallPath(.header, ".");
    const dep = b.dependency("cmark-gfm", .{
        .target = target,
        .optimize = optimize,
    });

    const config = b.addConfigHeader(
        .{ .style = .{ .cmake = dep.path("src/config.h.in") } },
        .{ .HAVE_STDBOOL_H = true },
    );

    const version = b.addConfigHeader(
        .{ .style = .{ .cmake = dep.path("src/cmark-gfm_version.h.in") } },
        .{
            .PROJECT_VERSION_MAJOR = "0",
            .PROJECT_VERSION_MINOR = "29",
            .PROJECT_VERSION_PATCH = "0",
            .PROJECT_VERSION_GFM = "13",
        },
    );

    const localIncludes = b.path("include"); // for cmark-gfm_export.h

    const lib = b.addStaticLibrary(.{
        .name = "cmark-gfm",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    b.installArtifact(lib);
    lib.addConfigHeader(config);
    lib.addConfigHeader(version);
    lib.addIncludePath(localIncludes);
    lib.addIncludePath(.{ .cwd_relative = header_install_dir });

    // Make headers available for cImport.
    lib.installConfigHeader(version);
    lib.installHeader(localIncludes.path(b, "cmark-gfm_export.h"), "cmark-gfm_export.h");
    lib.installHeader(dep.path("src/cmark-gfm.h"), "cmark-gfm.h");
    lib.installHeader(dep.path("src/cmark-gfm-extension_api.h"), "cmark-gfm-extension_api.h");

    lib.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = cmark_gfm_lib_src,
        .flags = &.{"-std=c99"},
    });

    const ext_lib = b.addStaticLibrary(.{
        .name = "cmark-gfm-extensions",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    b.installArtifact(ext_lib);
    ext_lib.addConfigHeader(config);
    ext_lib.addIncludePath(dep.path("src"));
    ext_lib.installHeader(dep.path("extensions/cmark-gfm-core-extensions.h"), "cmark-gfm-core-extensions.h");
    ext_lib.installHeader(dep.path("extensions/ext_scanners.h"), "ext_scanners.h");
    ext_lib.addCSourceFiles(.{
        .root = dep.path("extensions"),
        .files = cmark_gfm_extensions_src,
        .flags = &.{"-std=c99"},
    });
    ext_lib.linkLibrary(lib);

    // Build the executable
    const exe = b.addExecutable(.{
        .name = "zoe",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lib);
    exe.linkLibrary(ext_lib);
    b.installArtifact(exe);

    // Add test step
    const test_step = b.step("test", "Run library tests");

    // Create the test executable
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/test/zoe_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the module for the core library
    const core_module = b.addModule("core", .{
        .root_source_file = .{ .cwd_relative = "src/core/cli.zig" },
    });
    main_tests.root_module.addImport("core", core_module);

    // Add the module for the command modules
    const cmd_module = b.addModule("cmd", .{
        .root_source_file = .{ .cwd_relative = "src/cmd/commands.zig" },
    });
    main_tests.root_module.addImport("cmd", cmd_module);

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Always pass any arguments after -- to the program
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const cmark_gfm_extensions_src: []const []const u8 = &.{
    "core-extensions.c",
    "table.c",
    "strikethrough.c",
    "autolink.c",
    "tagfilter.c",
    "ext_scanners.c",
    "tasklist.c",
};

const cmark_gfm_lib_src: []const []const u8 = &.{
    "xml.c",
    "cmark.c",
    "man.c",
    "buffer.c",
    "blocks.c",
    "cmark_ctype.c",
    "inlines.c",
    "latex.c",
    "houdini_href_e.c",
    "syntax_extension.c",
    "houdini_html_e.c",
    "plaintext.c",
    "utf8.c",
    "references.c",
    "render.c",
    "iterator.c",
    "arena.c",
    "linked_list.c",
    "commonmark.c",
    "map.c",
    "html.c",
    "plugin.c",
    "scanners.c",
    "footnotes.c",
    "houdini_html_u.c",
    "registry.c",
    "node.c",
};
