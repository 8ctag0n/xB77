const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .abi = .gnu, .os_tag = .linux },
    });
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
    core_module.addIncludePath(b.path("deps"));

    // --- MCP Module ---
    const mcp_module = b.addModule("mcp", .{
        .root_source_file = b.path("apps/mcp/server.zig"),
        .imports = &.{
            .{ .name = "core", .module = core_module },
        },
    });

    // --- Native CLI ---
    const exe = b.addExecutable(.{
        .name = "xb77",
        .root_module = b.createModule(.{
            .root_source_file = b.path("apps/cli/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.pie = false;
    exe.root_module.addImport("core", core_module);
    exe.root_module.addImport("mcp", mcp_module);
    exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check", "-fPIC", "-fno-sanitize=all", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables"} });
    exe.root_module.strip = true;
    exe.root_module.omit_frame_pointer = true;
    exe.root_module.stack_check = false;
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
    znode_exe.addCSourceFile(.{ .file = b.path("apps/znode/main.c"), .flags = &.{"-std=c11"} });
    znode_exe.addCSourceFile(.{ .file = b.path("deps/znode.c"), .flags = &.{"-std=c11"} });
    znode_exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    znode_exe.addIncludePath(b.path("deps"));
    znode_exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
    znode_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    // Debian/Ubuntu place libcurl under a multi-arch path (e.g.
    // /usr/lib/x86_64-linux-gnu). Only add it when it actually exists,
    // otherwise Zig 0.15 errors with "unable to open library directory".
    for ([_][]const u8{
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib/aarch64-linux-gnu",
    }) |multiarch| {
        if (std.fs.accessAbsolute(multiarch, .{})) |_| {
            znode_exe.addLibraryPath(.{ .cwd_relative = multiarch });
        } else |_| {}
    }
    znode_exe.root_module.strip = true;
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
    e2e_exe.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check", "-fPIC", "-fno-sanitize=all", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables"} });
    e2e_exe.root_module.strip = true;
    e2e_exe.root_module.omit_frame_pointer = true;
    e2e_exe.root_module.stack_check = false;
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
    // Stays on wasi because core/* depends on std.posix surfaces (clockid_t,
    // getrandom, writev) which don't exist on freestanding wasm. Cloudflare
    // Workers can polyfill the few WASI imports that survive (or we shim
    // them in worker.js). The real fix to the empty-binary-stub problem is
    // entry = .disabled + rdynamic — without those, the linker DCE'd every
    // `export fn` because nothing was reachable from _start.
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const wasm_gateway = b.addExecutable(.{
        .name = "gateway",
        .root_module = b.createModule(.{
            .root_source_file = b.path("apps/gateway/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });
    wasm_gateway.root_module.addImport("core", core_module);
    wasm_gateway.entry = .disabled;
    wasm_gateway.rdynamic = true;

    const install_wasm = b.addInstallArtifact(wasm_gateway, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    
    const wasm_step = b.step("wasm", "Build the Gateway WASM binary for Cloudflare Workers");
    wasm_step.dependOn(&install_wasm.step);

    // --- Arbitrum Stylus (Zig Native Contract) ---
    const stylus_wasm = b.addExecutable(.{
        .name = "constitution",
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });
    stylus_wasm.root_module.addImport("core", core_module);
    stylus_wasm.entry = .disabled;
    stylus_wasm.rdynamic = true;

    const install_stylus = b.addInstallArtifact(stylus_wasm, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    const stylus_step = b.step("stylus", "Build the Zig-native Arbitrum Stylus contract");
    stylus_step.dependOn(&install_stylus.step);

    // --- SDK Core WASM (xb77_core.wasm) ---
    // Stateless SDK surface compiled to wasm32-wasi. Wrappers (TS/Py/Rust)
    // polyfill the small set of WASI imports actually used. See
    // docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.addendum.md §A.9
    const sdk_wasm = b.addExecutable(.{
        .name = "xb77_core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/wasm/exports.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });
    sdk_wasm.root_module.addImport("core", core_module);
    sdk_wasm.entry = .disabled;
    sdk_wasm.rdynamic = true;

    const install_sdk_wasm = b.addInstallArtifact(sdk_wasm, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });

    const sdk_wasm_step = b.step("sdk-wasm", "Build the xB77 SDK core WASM (xb77_core.wasm)");
    sdk_wasm_step.dependOn(&install_sdk_wasm.step);

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
    brain_unit_tests.linkLibC();
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
        .root_source_file = b.path("sdk/zig/merchant_sdk.zig"),
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

    // --- E2E ZK Upload (drives core/chain/zk_uploader.zig) ---
    const zk_upload_e2e = b.addExecutable(.{
        .name = "zk-upload-e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zk_upload_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    zk_upload_e2e.root_module.addImport("core", core_module);
    zk_upload_e2e.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    zk_upload_e2e.addIncludePath(b.path("deps"));
    zk_upload_e2e.linkLibC();
    b.installArtifact(zk_upload_e2e);

    // --- E2E Compression VerifyTransition (sends real tx to xb77_compression) ---
    const compression_e2e = b.addExecutable(.{
        .name = "compression-e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/compression_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    compression_e2e.root_module.addImport("core", core_module);
    compression_e2e.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    compression_e2e.addIncludePath(b.path("deps"));
    compression_e2e.linkLibC();
    b.installArtifact(compression_e2e);

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
            .root_source_file = b.path("sdk/zig/xb77_sdk.zig"),
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
            .root_source_file = b.path("sdk/zig/merchant_sdk.zig"),
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
            .root_source_file = b.path("sdk/zig/merchant_sdk.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });
    merchant_wasm.root_module.addImport("core", core_module);
    merchant_wasm.entry = .disabled;
    merchant_wasm.rdynamic = true;

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

    // --- Onchain unit tests (wincode + IDL client + solana_tx) ---
    const onchain_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/onchain_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    onchain_unit_tests.root_module.addImport("core", core_module);
    onchain_unit_tests.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    onchain_unit_tests.addIncludePath(b.path("deps"));
    onchain_unit_tests.linkLibC();
    const run_onchain_unit_tests = b.addRunArtifact(onchain_unit_tests);

    // --- Trident Smoke Test ---
    const trident_smoke = b.addExecutable(.{
        .name = "trident-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/trident_smoke.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    trident_smoke.root_module.addImport("core", core_module);
    trident_smoke.root_module.addIncludePath(b.path("deps"));
    trident_smoke.linkLibC();
    b.installArtifact(trident_smoke);

    const run_trident_smoke = b.addRunArtifact(trident_smoke);
    const trident_smoke_step = b.step("trident-smoke", "Run the Trident Integration Smoke Test");
    trident_smoke_step.dependOn(&run_trident_smoke.step);

    const agora_arc_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/agora_arc_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    agora_arc_unit_tests.root_module.addImport("core", core_module);
    const run_agora_arc_unit_tests = b.addRunArtifact(agora_arc_unit_tests);

    const semantic_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/semantic_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    semantic_unit_tests.root_module.addImport("core", core_module);
    const run_semantic_unit_tests = b.addRunArtifact(semantic_unit_tests);

    const e2e_intelligence_exe = b.addExecutable(.{
        .name = "e2e-intelligence",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_intelligence.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_intelligence_exe.root_module.addImport("core", core_module);
    b.installArtifact(e2e_intelligence_exe);

    const local_arb_test_exe = b.addExecutable(.{
        .name = "local_arb_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/local_arbitrum_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    local_arb_test_exe.root_module.addImport("core", core_module);
    b.installArtifact(local_arb_test_exe);

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
    test_step.dependOn(&run_onchain_unit_tests.step);
    test_step.dependOn(&run_agora_arc_unit_tests.step);
    test_step.dependOn(&run_semantic_unit_tests.step);
}
