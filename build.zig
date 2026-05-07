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
    exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check"} });
    exe.addIncludePath(b.path("deps"));
    exe.linkLibC();

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
    znode_exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    znode_exe.addIncludePath(b.path("deps"));
    znode_exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
    znode_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
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
    e2e_exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    e2e_exe.addIncludePath(b.path("deps"));
    e2e_exe.linkLibC();
    b.installArtifact(e2e_exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // --- WASM Target (Cloudflare Workers) ---
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const wasm_gateway = b.addExecutable(.{
        .name = "gateway",
        .root_module = b.createModule(.{
            .root_source_file = b.path("gateway/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });
    wasm_gateway.root_module.addImport("core", core_module);

    const install_wasm = b.addInstallArtifact(wasm_gateway, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    
    const wasm_step = b.step("wasm", "Build the Gateway WASM binary for Cloudflare Workers");
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
    store_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    store_unit_tests.addIncludePath(b.path("deps"));
    store_unit_tests.linkLibC();
    const run_store_unit_tests = b.addRunArtifact(store_unit_tests);

    const zk_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zk_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    zk_unit_tests.root_module.addImport("core", core_module);
    zk_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    zk_unit_tests.addIncludePath(b.path("deps"));
    zk_unit_tests.linkLibC();
    const run_zk_unit_tests = b.addRunArtifact(zk_unit_tests);

    const cmt_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/cmt_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    cmt_unit_tests.root_module.addImport("core", core_module);
    cmt_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    cmt_unit_tests.addIncludePath(b.path("deps"));
    cmt_unit_tests.linkLibC();
    const run_cmt_unit_tests = b.addRunArtifact(cmt_unit_tests);

    const ghost_proof_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/ghost_proof_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    ghost_proof_unit_tests.root_module.addImport("core", core_module);
    ghost_proof_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    ghost_proof_unit_tests.addIncludePath(b.path("deps"));
    ghost_proof_unit_tests.linkLibC();
    const run_ghost_proof_unit_tests = b.addRunArtifact(ghost_proof_unit_tests);

    const awp_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/awp_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    awp_unit_tests.root_module.addImport("core", core_module);
    const run_awp_unit_tests = b.addRunArtifact(awp_unit_tests);

    const brain_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/brain_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    brain_unit_tests.root_module.addImport("core", core_module);
    const run_brain_unit_tests = b.addRunArtifact(brain_unit_tests);

    const merchant_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/merchant_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    merchant_unit_tests.root_module.addImport("core", core_module);
    const sdk_module = b.createModule(.{
        .root_source_file = b.path("sdk/merchant_sdk.zig"),
    });
    sdk_module.addImport("core", core_module);
    merchant_unit_tests.root_module.addImport("sdk", sdk_module);
    const run_merchant_unit_tests = b.addRunArtifact(merchant_unit_tests);

    const app_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/app_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    app_unit_tests.root_module.addImport("core", core_module);
    app_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    app_unit_tests.addIncludePath(b.path("deps"));
    app_unit_tests.linkLibC();
    const run_app_unit_tests = b.addRunArtifact(app_unit_tests);

    const compression_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/compression_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    compression_unit_tests.root_module.addImport("core", core_module);
    compression_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    compression_unit_tests.addIncludePath(b.path("deps"));
    compression_unit_tests.linkLibC();
    const run_compression_unit_tests = b.addRunArtifact(compression_unit_tests);

    const strategist_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/strategist_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    strategist_unit_tests.root_module.addImport("core", core_module);
    strategist_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    strategist_unit_tests.addIncludePath(b.path("deps"));
    strategist_unit_tests.linkLibC();
    const run_strategist_unit_tests = b.addRunArtifact(strategist_unit_tests);

    const orchestrator_e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/orchestrator_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    orchestrator_e2e_tests.root_module.addImport("core", core_module);
    const run_orchestrator_e2e_tests = b.addRunArtifact(orchestrator_e2e_tests);

    const orchestrator_potent_e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/orchestrator_potent_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    orchestrator_potent_e2e_tests.root_module.addImport("core", core_module);
    const run_orchestrator_potent_e2e_tests = b.addRunArtifact(orchestrator_potent_e2e_tests);

    const ghost_payment_e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/ghost_payment_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    ghost_payment_e2e_tests.root_module.addImport("core", core_module);
    ghost_payment_e2e_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    ghost_payment_e2e_tests.addIncludePath(b.path("deps"));
    ghost_payment_e2e_tests.linkLibC();
    const run_ghost_payment_e2e_tests = b.addRunArtifact(ghost_payment_e2e_tests);

    // --- RPC Check Utility ---
    const rpc_check = b.addExecutable(.{
        .name = "rpc-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/check_rpc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    rpc_check.root_module.addImport("core", core_module);
    rpc_check.linkLibC();
    b.installArtifact(rpc_check);

    // --- E2E Sovereign Anchor Test ---
    const e2e_anchor = b.addExecutable(.{
        .name = "e2e-anchor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_solana_anchor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_anchor.root_module.addImport("core", core_module);
    e2e_anchor.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    e2e_anchor.addIncludePath(b.path("deps"));
    e2e_anchor.linkLibC();
    b.installArtifact(e2e_anchor);

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

    // --- SNS Resolution Test ---
    const sns_test = b.addExecutable(.{
        .name = "sns-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/sns_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    sns_test.root_module.addImport("core", core_module);
    sns_test.linkLibC();
    b.installArtifact(sns_test);
    // --- Merchant SDK (Standalone Package) ---
    const merchant_sdk = b.addLibrary(.{
        .name = "xb77_merchant",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/merchant_sdk.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });
    merchant_sdk.root_module.addImport("core", core_module);
    b.installArtifact(merchant_sdk);

    // --- Merchant SDK WASM (for Browsers/Apps) ---
    const merchant_wasm = b.addExecutable(.{
        .name = "xb77_merchant",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/merchant_sdk.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });
    merchant_wasm.root_module.addImport("core", core_module);
    
    const install_merchant_wasm = b.addInstallArtifact(merchant_wasm, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    const merchant_wasm_step = b.step("merchant-wasm", "Build the Merchant SDK as WASM");
    merchant_wasm_step.dependOn(&install_merchant_wasm.step);

    const negotiation_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/negotiation_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    negotiation_unit_tests.root_module.addImport("core", core_module);
    const run_negotiation_unit_tests = b.addRunArtifact(negotiation_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_crypto_unit_tests.step);
    test_step.dependOn(&run_tx_unit_tests.step);
    test_step.dependOn(&run_store_unit_tests.step);
    test_step.dependOn(&run_zk_unit_tests.step);
    test_step.dependOn(&run_cmt_unit_tests.step);
    test_step.dependOn(&run_ghost_proof_unit_tests.step);
    test_step.dependOn(&run_awp_unit_tests.step);
    test_step.dependOn(&run_brain_unit_tests.step);
    test_step.dependOn(&run_merchant_unit_tests.step);
    test_step.dependOn(&run_app_unit_tests.step);
    test_step.dependOn(&run_compression_unit_tests.step);
    test_step.dependOn(&run_strategist_unit_tests.step);
    test_step.dependOn(&run_orchestrator_e2e_tests.step);
    test_step.dependOn(&run_orchestrator_potent_e2e_tests.step);
    test_step.dependOn(&run_ghost_payment_e2e_tests.step);
    test_step.dependOn(&run_negotiation_unit_tests.step);
}
