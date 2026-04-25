const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- AWP Universal Module ---
    const awp_module = b.addModule("awp", .{
        .root_source_file = b.path("deps/awp/src/root.zig"),
    });

    // --- Core Module ---
    const core_module = b.addModule("core", .{
        .root_source_file = b.path("core/core.zig"),
        .imports = &.{
            .{ .name = "awp", .module = awp_module },
        },
    });

    // --- MCP Module ---
    const mcp_module = b.addModule("mcp", .{
        .root_source_file = b.path("mcp/server.zig"),
        .imports = &.{
            .{ .name = "core", .module = core_module },
        },
    });

    // --- Native CLI ---
    const exe = b.addExecutable(.{
        .name = "xb77",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cli/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("core", core_module);
    exe.root_module.addImport("mcp", mcp_module);

    b.installArtifact(exe);

    // --- Z-Node Server (C + Zig Bridge) ---
    const znode_exe = b.addExecutable(.{
        .name = "znode-server",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    znode_exe.addCSourceFile(.{ .file = b.path("znode/main.c"), .flags = &.{"-std=c11"} });
    znode_exe.addCSourceFile(.{ .file = b.path("deps/znode.c"), .flags = &.{"-std=c11"} });
    znode_exe.addIncludePath(b.path("deps"));
    znode_exe.linkLibC();
    znode_exe.linkSystemLibrary("curl");

    b.installArtifact(znode_exe);

    // --- Z-Node E2E Lab ---
    const e2e_exe = b.addExecutable(.{
        .name = "znode-e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/znode_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_exe.root_module.addImport("core", core_module);
    b.installArtifact(e2e_exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // --- WASM Target ---
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const wasm_exe = b.addExecutable(.{
        .name = "xb77",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cli/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });
    wasm_exe.root_module.addImport("core", core_module);
    wasm_exe.root_module.addImport("mcp", mcp_module);

    const install_wasm = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    
    const wasm_step = b.step("wasm", "Build the WASM binary for Cloudflare Workers");
    wasm_step.dependOn(&install_wasm.step);

    // --- Tests ---
    const crypto_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/crypto_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    crypto_unit_tests.root_module.addImport("core", core_module);

    const run_crypto_unit_tests = b.addRunArtifact(crypto_unit_tests);

    const tx_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/tx_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tx_unit_tests.root_module.addImport("core", core_module);
    const run_tx_unit_tests = b.addRunArtifact(tx_unit_tests);

    const store_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/store_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    store_unit_tests.root_module.addImport("core", core_module);
    const run_store_unit_tests = b.addRunArtifact(store_unit_tests);

    const zk_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zk_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    zk_unit_tests.root_module.addImport("core", core_module);
    const run_zk_unit_tests = b.addRunArtifact(zk_unit_tests);

    const awp_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/awp_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    awp_unit_tests.root_module.addImport("core", core_module);
    const run_awp_unit_tests = b.addRunArtifact(awp_unit_tests);

    // --- Mesh P2P Ping ---
    const mesh_ping_exe = b.addExecutable(.{
        .name = "mesh-ping",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/mesh_ping.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    mesh_ping_exe.root_module.addImport("core", core_module);
    b.installArtifact(mesh_ping_exe);

    // --- Mesh Waterfall Test ---
    const mesh_waterfall_exe = b.addExecutable(.{
        .name = "mesh-waterfall",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/mesh_waterfall.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    mesh_waterfall_exe.root_module.addImport("core", core_module);
    b.installArtifact(mesh_waterfall_exe);

    // --- Benchmarks ---
    const bench_exe = b.addExecutable(.{
        .name = "awp-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/bench_awp.zig"),
            .target = target,
            .optimize = .ReleaseFast, // Performance real
        }),
    });
    bench_exe.root_module.addImport("core", core_module);
    b.installArtifact(bench_exe);

    // --- xB77 SDK (Shared Lib for TS/Python/C Wrappers) ---
    const sdk_lib = b.addLibrary(.{
        .name = "xb77_sdk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/xb77_sdk.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });
    sdk_lib.root_module.addImport("core", core_module);
    b.installArtifact(sdk_lib);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_crypto_unit_tests.step);
    test_step.dependOn(&run_tx_unit_tests.step);
    test_step.dependOn(&run_store_unit_tests.step);
    test_step.dependOn(&run_zk_unit_tests.step);
    test_step.dependOn(&run_awp_unit_tests.step);
}
