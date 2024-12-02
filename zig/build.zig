const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const profile = b.option(bool, "profile", "Enables the profiler") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "profile", profile);

    const src_dir = "src";
    const data_dir = "../data";
    var dir = try std.fs.cwd().openDir(src_dir, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
                if (!std.mem.startsWith(u8, entry.name, "day")) continue;

                const stem = std.fs.path.stem(entry.name);

                const filename = b.pathJoin(&.{ src_dir, entry.name });
                const exe = b.addExecutable(.{
                    .name = stem,
                    .root_source_file = b.path(filename),
                    .target = target,
                    .optimize = optimize,
                });

                const input_path = b.pathJoin(&.{ data_dir, stem });
                exe.root_module.addAnonymousImport("input", .{ .root_source_file = b.path(input_path) });
                exe.root_module.addOptions("build_options", build_options);
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                run_cmd.step.dependOn(b.getInstallStep());

                if (b.args) |args| {
                    run_cmd.addArgs(args);
                }

                const run_step = b.step(stem, "Run the day");
                run_step.dependOn(&run_cmd.step);
            },
            else => continue,
        }
    }
}
