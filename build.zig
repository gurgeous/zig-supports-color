const minimum_zig_version = std.SemanticVersion.parse(@import("build.zig.zon").minimum_zig_version) catch unreachable;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // check zig version
    comptime if (builtin.zig_version.order(minimum_zig_version) == .lt) {
        @compileError(std.fmt.comptimePrint(
            \\Uh oh, zig is too old.
            \\required: {[minimum_zig_version]f}
            \\actual:   {[current_version]f}
            \\
        , .{
            .current_version = builtin.zig_version,
            .minimum_zig_version = minimum_zig_version,
        }));
    };

    //
    // lib
    //

    const mod = b.addModule("supports_color", .{
        .root_source_file = b.path("supports_color.zig"),
        .optimize = optimize,
        .target = target,
    });

    //
    // tests
    //

    const unit_tests = b.addTest(.{ .root_module = mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    b.step("test", "Run tests").dependOn(&run_unit_tests.step);

    //
    // main.zig
    //

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "supports_color", .module = mod }},
    });

    const main = b.addExecutable(.{ .name = "zig-supports-color", .root_module = main_mod });
    b.installArtifact(main);
}

const builtin = @import("builtin");
const std = @import("std");
