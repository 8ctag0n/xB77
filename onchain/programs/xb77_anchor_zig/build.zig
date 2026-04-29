const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .bpfel,
        .os_tag = .freestanding,
        .cpu_model = .{.explicit = &std.Target.bpf.cpu.v3},
    });

    const exe = b.addExecutable(.{
        .name = "xb77_anchor_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });

    b.installArtifact(exe);
}
