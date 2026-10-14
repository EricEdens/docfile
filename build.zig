const std = @import("std");

pub fn build(b: *std.Build) void {
    const mod = b.addModule("docfile", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&run_tests.step);
}
