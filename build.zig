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
    exe.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check", "-fPIC", "-fno-sanitize=all", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables"} });
    exe.root_module.strip = true;
    exe.root_module.omit_frame_pointer = true;
    exe.root_module.stack_check = false;
    exe.root_module.addIncludePath(b.path("deps"));
    exe.root_module.linkSystemLibrary("c", .{});

    b.installArtifact(exe);

    // --- Z-Node Server (C + Zig Bridge) ---
    const znode_exe = b.addExecutable(.{
        .name = "znode-server",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    znode_exe.root_module.addCSourceFile(.{ .file = b.path("apps/znode/main.c"), .flags = &.{"-std=c11"} });
    znode_exe.root_module.addCSourceFile(.{ .file = b.path("deps/znode.c"), .flags = &.{"-std=c11"} });
    znode_exe.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    znode_exe.root_module.addIncludePath(b.path("deps"));
    znode_exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include" });
    znode_exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    // Debian/Ubuntu place libcurl under a multi-arch path (e.g.
    // /usr/lib/x86_64-linux-gnu). Only add it when it actually exists,
    // otherwise Zig 0.15 errors with "unable to open library directory".
    for ([_][]const u8{
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib/aarch64-linux-gnu",
    }) |multiarch| {
        if (std.Io.Dir.accessAbsolute(b.graph.io, multiarch, .{})) |_| {
            znode_exe.root_module.addLibraryPath(.{ .cwd_relative = multiarch });
        } else |_| {}
    }
    znode_exe.root_module.strip = true;
    znode_exe.root_module.linkSystemLibrary("c", .{});
    znode_exe.root_module.linkSystemLibrary("curl", .{});

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
    e2e_exe.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check", "-fPIC", "-fno-sanitize=all", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables"} });
    e2e_exe.root_module.strip = true;
    e2e_exe.root_module.omit_frame_pointer = true;
    e2e_exe.root_module.stack_check = false;
    e2e_exe.root_module.addIncludePath(b.path("deps"));
    e2e_exe.root_module.linkSystemLibrary("c", .{});
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
    // Shared wasm32-freestanding target for all Stylus contracts
    const stylus_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Helper to create a Stylus WASM executable
    const StylusContract = struct {
        fn add(
            b2: *std.Build,
            name: []const u8,
            src: []const u8,
            core_mod: *std.Build.Module,
            st: std.Build.ResolvedTarget,
        ) *std.Build.Step.InstallArtifact {
            const contract = b2.addExecutable(.{
                .name = name,
                .root_module = b2.createModule(.{
                    .root_source_file = b2.path(src),
                    .target = st,
                    .optimize = .ReleaseSmall,
                    .strip = true,
                }),
            });
            contract.root_module.addImport("core", core_mod);
            contract.entry = .disabled;
            contract.rdynamic = true;
            return b2.addInstallArtifact(contract, .{
                .dest_dir = .{ .override = .{ .custom = "bin" } },
            });
        }
    };

    const install_constitution  = StylusContract.add(b, "constitution",     "onchain/stylus/main.zig",              core_module, stylus_target);
    const install_settlement    = StylusContract.add(b, "settlement",       "onchain/stylus/settlement.zig",        core_module, stylus_target);
    const install_univ4_hook    = StylusContract.add(b, "uniswap_hook",    "onchain/stylus/uniswap_hook.zig",      core_module, stylus_target);
    const install_aave_guard    = StylusContract.add(b, "aave_guard",      "onchain/stylus/aave_guard.zig",        core_module, stylus_target);
    const install_gmx_guard     = StylusContract.add(b, "gmx_guard",       "onchain/stylus/gmx_guard.zig",        core_module, stylus_target);
    const install_groth16       = StylusContract.add(b, "groth16_verifier","onchain/stylus/groth16_verifier.zig", core_module, stylus_target);

    const stylus_step = b.step("stylus", "Build all Zig-native Arbitrum Stylus contracts");
    stylus_step.dependOn(&install_constitution.step);
    stylus_step.dependOn(&install_settlement.step);
    stylus_step.dependOn(&install_univ4_hook.step);
    stylus_step.dependOn(&install_aave_guard.step);
    stylus_step.dependOn(&install_gmx_guard.step);
    stylus_step.dependOn(&install_groth16.step);

    // Stylus local test suite (native build, uses mock_hooks.zig)
    const stylus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/test_stylus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    stylus_tests.root_module.addImport("core", core_module);
    const run_stylus_tests = b.addRunArtifact(stylus_tests);
    const stylus_test_step = b.step("test-stylus", "Run Stylus contract tests locally (no chain needed)");
    stylus_test_step.dependOn(&run_stylus_tests.step);

    // ABI unit tests (no vm_hooks dependency — runs natively)
    const abi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/test_abi.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_abi_tests = b.addRunArtifact(abi_tests);
    const abi_test_step = b.step("test-abi", "Run ABI encoder/decoder unit tests");
    abi_test_step.dependOn(&run_abi_tests.step);

    // BN254 pure-WASM unit tests (fp.zig + g1.zig — no vm_hooks, no C deps)
    const bn254_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/bn254/g1.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_bn254_tests = b.addRunArtifact(bn254_tests);
    const bn254_test_step = b.step("test-bn254", "Run BN254 Fp + G1 arithmetic unit tests");
    bn254_test_step.dependOn(&run_bn254_tests.step);

    // BN254 Fp2 + G2 unit tests
    const bn254_fp2_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/bn254/g2.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_bn254_fp2_tests = b.addRunArtifact(bn254_fp2_tests);
    const bn254_fp2_test_step = b.step("test-bn254-g2", "Run BN254 Fp2 + G2 arithmetic unit tests");
    bn254_fp2_test_step.dependOn(&run_bn254_fp2_tests.step);

    // BN254 pairing unit tests (fp6 + fp12 + optimal Ate)
    const bn254_pairing_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/bn254/pairing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_bn254_pairing_tests = b.addRunArtifact(bn254_pairing_tests);
    const bn254_pairing_test_step = b.step("test-bn254-pairing", "Run BN254 optimal Ate pairing + Fp6/Fp12 unit tests");
    bn254_pairing_test_step.dependOn(&run_bn254_pairing_tests.step);

    // BN254 Groth16 verifier unit tests
    const groth16_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/bn254/groth16.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_groth16_tests = b.addRunArtifact(groth16_tests);
    const groth16_test_step = b.step("test-groth16", "Run Groth16 verifier unit tests");
    groth16_test_step.dependOn(&run_groth16_tests.step);

    const groth16_heavy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/bn254/groth16_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_groth16_heavy = b.addRunArtifact(groth16_heavy_tests);
    const groth16_heavy_step = b.step("test-groth16-heavy", "Golden vectors, tamper, invariants, stress");
    groth16_heavy_step.dependOn(&run_groth16_heavy.step);

    const groth16_contract_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("onchain/stylus/test_groth16_verifier.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_groth16_contract = b.addRunArtifact(groth16_contract_tests);
    const groth16_contract_step = b.step("test-groth16-contract", "Integration tests for the Stylus contract (mock_hooks)");
    groth16_contract_step.dependOn(&run_groth16_contract.step);

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
    store_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    store_unit_tests.root_module.addIncludePath(b.path("deps"));
    store_unit_tests.root_module.linkSystemLibrary("c", .{});
    const run_store_unit_tests = b.addRunArtifact(store_unit_tests);

    // Dedicated step to regenerate circuits/state_anchor/Prover.toml from a real
    // CMT run (gated by XB77_GEN_ANCHOR so it's skipped in the normal test suite).
    const gen_anchor_run = b.addRunArtifact(store_unit_tests);
    gen_anchor_run.setEnvironmentVariable("XB77_GEN_ANCHOR", "1");
    gen_anchor_run.has_side_effects = true;
    const gen_anchor_step = b.step("gen-anchor-witness", "Regenerate state_anchor Prover.toml from a real CMT run");
    gen_anchor_step.dependOn(&gen_anchor_run.step);

    const zk_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zk_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    zk_unit_tests.root_module.addImport("core", core_module);
    zk_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    zk_unit_tests.root_module.addIncludePath(b.path("deps"));
    zk_unit_tests.root_module.linkSystemLibrary("c", .{});
    const run_zk_unit_tests = b.addRunArtifact(zk_unit_tests);

    const cmt_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/cmt_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    cmt_unit_tests.root_module.addImport("core", core_module);
    cmt_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    cmt_unit_tests.root_module.addIncludePath(b.path("deps"));
    cmt_unit_tests.root_module.linkSystemLibrary("c", .{});
    const run_cmt_unit_tests = b.addRunArtifact(cmt_unit_tests);

    const ghost_proof_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/ghost_proof_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    ghost_proof_unit_tests.root_module.addImport("core", core_module);
    ghost_proof_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    ghost_proof_unit_tests.root_module.addIncludePath(b.path("deps"));
    ghost_proof_unit_tests.root_module.linkSystemLibrary("c", .{});
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
    brain_unit_tests.root_module.linkSystemLibrary("c", .{});
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
    app_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    app_unit_tests.root_module.addIncludePath(b.path("deps"));
    app_unit_tests.root_module.linkSystemLibrary("c", .{});
    const run_app_unit_tests = b.addRunArtifact(app_unit_tests);

    const compression_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/compression_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    compression_unit_tests.root_module.addImport("core", core_module);
    compression_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    compression_unit_tests.root_module.addIncludePath(b.path("deps"));
    compression_unit_tests.root_module.linkSystemLibrary("c", .{});
    const run_compression_unit_tests = b.addRunArtifact(compression_unit_tests);

    const strategist_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/strategist_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    strategist_unit_tests.root_module.addImport("core", core_module);
    strategist_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    strategist_unit_tests.root_module.addIncludePath(b.path("deps"));
    strategist_unit_tests.root_module.linkSystemLibrary("c", .{});
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
    ghost_payment_e2e_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    ghost_payment_e2e_tests.root_module.addIncludePath(b.path("deps"));
    ghost_payment_e2e_tests.root_module.linkSystemLibrary("c", .{});
    const run_ghost_payment_e2e_tests = b.addRunArtifact(ghost_payment_e2e_tests);

    // --- Full Local E2E (all systems connected) ---
    const e2e_full_local_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_full_local.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_full_local_tests.root_module.addImport("core", core_module);
    e2e_full_local_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    e2e_full_local_tests.root_module.addIncludePath(b.path("deps"));
    e2e_full_local_tests.root_module.linkSystemLibrary("c", .{});
    const run_e2e_full_local_tests = b.addRunArtifact(e2e_full_local_tests);

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
    rpc_check.root_module.linkSystemLibrary("c", .{});
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
    e2e_anchor.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    e2e_anchor.root_module.addIncludePath(b.path("deps"));
    e2e_anchor.root_module.linkSystemLibrary("c", .{});
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
    zk_upload_e2e.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    zk_upload_e2e.root_module.addIncludePath(b.path("deps"));
    zk_upload_e2e.root_module.linkSystemLibrary("c", .{});
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
    compression_e2e.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    compression_e2e.root_module.addIncludePath(b.path("deps"));
    compression_e2e.root_module.linkSystemLibrary("c", .{});
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
    sns_test.root_module.linkSystemLibrary("c", .{});
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
    onchain_unit_tests.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11"} });
    onchain_unit_tests.root_module.addIncludePath(b.path("deps"));
    onchain_unit_tests.root_module.linkSystemLibrary("c", .{});
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
    trident_smoke.root_module.linkSystemLibrary("c", .{});
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

    const anvil_e2e_exe = b.addExecutable(.{
        .name = "anvil-e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/anvil_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    anvil_e2e_exe.root_module.addImport("core", core_module);
    anvil_e2e_exe.root_module.addCSourceFile(.{ .file = b.path("deps/cmt_core.c"), .flags = &.{"-std=c11", "-fno-stack-check", "-fPIC", "-fno-sanitize=all", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables"} });
    anvil_e2e_exe.root_module.addIncludePath(b.path("deps"));
    anvil_e2e_exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include" });
    anvil_e2e_exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    for ([_][]const u8{ "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu" }) |multiarch| {
        if (std.Io.Dir.accessAbsolute(b.graph.io, multiarch, .{})) |_| {
            anvil_e2e_exe.root_module.addLibraryPath(.{ .cwd_relative = multiarch });
        } else |_| {}
    }
    anvil_e2e_exe.root_module.linkSystemLibrary("c", .{});
    anvil_e2e_exe.root_module.linkSystemLibrary("curl", .{});
    b.installArtifact(anvil_e2e_exe);

    // ── New Stylus contracts: anchor, settlement_engine, zk_verifier ─────────
    const install_anchor     = StylusContract.add(b, "xb77_anchor",            "onchain/stylus/anchor.zig",            core_module, stylus_target);
    const install_settlement_engine = StylusContract.add(b, "xb77_settlement_engine", "onchain/stylus/settlement_engine.zig", core_module, stylus_target);
    const install_zk_verifier     = StylusContract.add(b, "xb77_zk_verifier",      "onchain/stylus/zk_verifier.zig",      core_module, stylus_target);
    const install_verifier_registry = StylusContract.add(b, "xb77_verifier_registry", "onchain/stylus/verifier_registry.zig", core_module, stylus_target);
    stylus_step.dependOn(&install_anchor.step);
    stylus_step.dependOn(&install_settlement_engine.step);
    stylus_step.dependOn(&install_zk_verifier.step);
    stylus_step.dependOn(&install_verifier_registry.step);

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
    test_step.dependOn(&run_e2e_full_local_tests.step);
    test_step.dependOn(&run_negotiation_unit_tests.step);
    test_step.dependOn(&run_onchain_unit_tests.step);
    test_step.dependOn(&run_agora_arc_unit_tests.step);
    test_step.dependOn(&run_semantic_unit_tests.step);

    // ── e2e ZK Stylus test step (runs scripts/e2e_zk_stylus.sh) ──────────────
    // Requires a running Arbitrum Nitro dev node: docker compose up -d nitro
    const e2e_step = b.step("test-e2e", "Run e2e ZK Stylus flows against local Nitro node");
    const e2e_cmd = b.addSystemCommand(&.{ "bash", "scripts/e2e_zk_stylus.sh", "--skip-build" });
    e2e_step.dependOn(&install_zk_verifier.step);
    e2e_step.dependOn(&install_verifier_registry.step);
    e2e_step.dependOn(&e2e_cmd.step);
}
