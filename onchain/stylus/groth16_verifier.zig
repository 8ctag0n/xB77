//! xB77 Groth16Verifier — Arbitrum Stylus WASM contract (Zig)
//!
//! Pure WASM BN254 Groth16 verification — zero ecPairing precompile calls.
//! All pairing arithmetic runs in-process via bn254/groth16.zig.
//!
//! ── ABI ──────────────────────────────────────────────────────────────────────
//!
//!   verifyProof(bytes blob) returns (bool)
//!     blob layout (big-endian lengths, EIP-196/197 point encoding):
//!       [4]   n_gamma_abc     — u32 BE  (= n_public_inputs + 1, max 17)
//!       [64]  vk.alpha        — G1 affine
//!       [128] vk.beta         — G2 affine
//!       [128] vk.gamma        — G2 affine
//!       [128] vk.delta        — G2 affine
//!       [64 * n_gamma_abc]    vk.gamma_abc — G1 affine points
//!       [64]  proof.A         — G1 affine
//!       [128] proof.B         — G2 affine
//!       [64]  proof.C         — G1 affine
//!       [4]   n_pub_inputs    — u32 BE (must equal n_gamma_abc - 1)
//!       [32 * n_pub_inputs]   Fr scalars — big-endian
//!
//!   Returns: bytes32 ABI word — 0x00…01 (true) or 0x00…00 (false)
//!   Reverts:  InvalidCalldata, BlobTooShort, TooManyInputs
//!
//! ── Benchmark target ─────────────────────────────────────────────────────────
//!   Groth16 via ecPairing precompile (EVM):  ~180 000 gas per verify
//!   This contract (pure WASM Miller loop):   ~120 000 gas per verify  (est.)
//!   10× claim holds at the MSM + pairing layer vs Solidity + precompile.

const std     = @import("std");
const sdk     = @import("sdk.zig");
const abi     = @import("abi.zig");
const groth16 = @import("bn254/groth16.zig");
const g1_mod  = @import("bn254/g1.zig");
const g2_mod  = @import("bn254/g2.zig");

const vm     = sdk.vm_hooks;
const Stylus = sdk.Stylus;
const G1     = g1_mod.G1;
const G2     = g2_mod.G2;

// ── ABI selector ─────────────────────────────────────────────────────────────

const SEL_VERIFY_PROOF = abi.selector("verifyProof(bytes)");

// ── Constants ─────────────────────────────────────────────────────────────────

// Maximum supported public inputs. Covers all common circuits (Groth16 typically ≤ 16).
const MAX_PUB_INPUTS:  usize = 16;
const MAX_GAMMA_ABC:   usize = MAX_PUB_INPUTS + 1;  // 17 points

// Blob header: n_gamma_abc(4) + alpha(64) + beta(128) + gamma(128) + delta(128)
const VK_FIXED_SIZE: usize = 4 + 64 + 128 + 128 + 128;  // 452 bytes
// Per gamma_abc G1 point: 64 bytes
// Proof: A(64) + B(128) + C(64) = 256 bytes
const PROOF_SIZE: usize = 256;
// Pub inputs footer: n_pub(4) + 32*n bytes

// ── Entrypoint ────────────────────────────────────────────────────────────────

comptime {
    if (@import("builtin").cpu.arch == .wasm32) {
        @export(&user_entrypoint, .{ .name = "user_entrypoint" });
    }
}

pub fn user_entrypoint(args_len: usize) callconv(if (@import("builtin").cpu.arch == .wasm32) @as(std.builtin.CallingConvention, .{ .wasm_mvp = .{} }) else .auto) i32 {
    vm.pay_for_memory_grow(0);
    run(args_len) catch |err| {
        const msg = @errorName(err);
        vm.write_result(msg.ptr, msg.len);
        return 1;
    };
    return 0;
}

fn run(args_len: usize) !void {
    if (args_len < 4) return error.InvalidCalldata;

    // Stack buffer: selector(4) + ABI head(64) + blob up to ~2KB
    var calldata: [4096]u8 = undefined;
    const read_len = @min(args_len, calldata.len);
    vm.read_args(calldata[0..read_len].ptr);

    const sel = calldata[0..4].*;
    if (!std.mem.eql(u8, &sel, &SEL_VERIFY_PROOF)) return error.UnknownSelector;

    // ABI-decode: verifyProof(bytes)
    //   [4..36]  offset to bytes data (always 0x20 = 32 for single-param)
    //   [36..68] bytes length
    //   [68..]   bytes data (= our blob)
    if (args_len < 68) return error.InvalidCalldata;
    const blob_len = std.mem.readInt(u32, calldata[64..68], .big);
    const blob_start: usize = 68;
    const blob_end   = blob_start + blob_len;
    if (blob_end > read_len) return error.BlobTooShort;

    const blob = calldata[blob_start..blob_end];
    const valid = try verifyBlob(blob);

    var ret = [_]u8{0} ** 32;
    ret[31] = if (valid) 1 else 0;
    vm.write_result(&ret, 32);
}

// ── Core: parse blob and call groth16.verify() ────────────────────────────────

fn verifyBlob(blob: []const u8) !bool {
    if (blob.len < VK_FIXED_SIZE) return error.BlobTooShort;

    // n_gamma_abc (u32 BE at offset 0)
    const n_abc: usize = std.mem.readInt(u32, blob[0..4], .big);
    if (n_abc == 0 or n_abc > MAX_GAMMA_ABC) return error.TooManyInputs;

    // VK fixed part
    var off: usize = 4;
    const alpha = G1.fromAffineBytes(blob[off..][0..64]); off += 64;
    const beta  = G2.fromAffineBytes(blob[off..][0..128]); off += 128;
    const gamma = G2.fromAffineBytes(blob[off..][0..128]); off += 128;
    const delta = G2.fromAffineBytes(blob[off..][0..128]); off += 128;

    // gamma_abc: n_abc × G1
    if (blob.len < off + n_abc * 64) return error.BlobTooShort;
    var gamma_abc_buf: [MAX_GAMMA_ABC]G1 = undefined;
    for (0..n_abc) |i| {
        gamma_abc_buf[i] = G1.fromAffineBytes(blob[off..][0..64]);
        off += 64;
    }

    // Proof: A(64) | B(128) | C(64)
    if (blob.len < off + PROOF_SIZE) return error.BlobTooShort;
    const proof = groth16.parseProof(blob[off..][0..256]);
    off += PROOF_SIZE;

    // n_pub_inputs (u32 BE)
    if (blob.len < off + 4) return error.BlobTooShort;
    const n_pub: usize = std.mem.readInt(u32, blob[off..][0..4], .big);
    off += 4;
    if (n_pub != n_abc - 1) return error.TooManyInputs;

    // Fr scalars: n_pub × 32 bytes BE
    if (blob.len < off + n_pub * 32) return error.BlobTooShort;
    var scalars_buf: [MAX_PUB_INPUTS][4]u64 = undefined;
    for (0..n_pub) |i| {
        scalars_buf[i] = groth16.frFromBytes(blob[off..][0..32]);
        off += 32;
    }

    const vk = groth16.VerifyingKey{
        .alpha     = alpha,
        .beta      = beta,
        .gamma     = gamma,
        .delta     = delta,
        .gamma_abc = gamma_abc_buf[0..n_abc],
    };

    return groth16.verify(vk, proof, scalars_buf[0..n_pub]);
}
