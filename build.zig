const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    const root = b.createModule(.{
        .root_source_file = b.path("graph.zig"),
        .target = target,
        .optimize = optimize,
    });
    const libgraf = b.addLibrary(.{
        .name = "graf",
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
        .linkage = .static,
        .root_module = root,
        .use_llvm = false,
    });
    b.installArtifact(libgraf);
}
