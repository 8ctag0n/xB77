//! UltraPlonk verifier for the state_anchor circuit — Zig/Stylus
//!
//! Full Barretenberg v0.58 UltraPlonk verification algorithm:
//!   7-round Fiat-Shamir transcript (Keccak-based)
//!   6 gate widgets: permutation, plookup, arithmetic, sort, elliptic, aux
//!   Batch commitment accumulator (44 G1 operations, pure WASM BN254)
//!   Final KZG: 2-pair ecPairing precompile call
//!
//! circuit_size = 131072 (2^17), num_public_inputs = 3
//! Proof format (2240 bytes from `bb prove`):
//!   [0..96]    3 public inputs (initial_root, final_root, tax) — BE32 each
//!   [96..2240] 2144-byte UltraPlonk proof data:
//!     [0..704]    11 G1 commitments: W1 W2 W3 W4 S Z Z_LKP T1 T2 T3 T4
//!     [704..2016] 41 Fr evaluations (each 32 bytes BE)
//!     [2016..2144] 2 G1 opening points: PI_Z PI_Z_OMEGA

const std = @import("std");
const sdk = @import("sdk.zig");
const fr  = @import("bn254/fr.zig");
const g1  = @import("bn254/g1.zig");
const G1  = g1.G1;

const vm     = sdk.vm_hooks;
const Stylus = sdk.Stylus;

// ── VK constants (from Verifier.sol lines 17-68) ────────────────────────────────

const VK_N:              u64  = 0x20000;   // 131072
const VK_NUM_INPUTS:     u32  = 3;
const VK_OMEGA:          u256 = 0x1bf82deba7d74902c3708cc6e70e61f30512eca95655210e276e5858ce8f58e5;
const VK_DOMAIN_INV:     u256 = 0x30643640b9f82f90e83b698e5ea6179c7c05542e859533b48b9953a2f5360801;
const VK_OMEGA_INV:      u256 = 0x244cf010c43ca87237d8b00bf9dd50c4c01c7f086bd4e8c920e75251d96f0d22;

const G1P = [64]u8;  // affine G1 point (x ‖ y, each 32 bytes BE)

// VK G1 points from Verifier.sol loadVerificationKey()
const VK_Q1         = vkPoint(0x1ab0c79db1712b36ce5cff7976fc136b1a92fc18cf2959679f5ac7dc6caf1990, 0x2f49532a08c1e7f054f1168faf7bcae9c0af9f23c7639379400e8b85e82faa36);
const VK_Q2         = vkPoint(0x0d23f1fb30ed7c843e626c87c0214a0c6290c5bb0146f464077557e8425aed3c, 0x20ddc56cb33b4a6fa13b4d11fa269c315a2e010652d9adabf5035c0a1494b381);
const VK_Q3         = vkPoint(0x17da3635fa87dbac49c0d789f07acea2fab61d45eb3a49d41f70690f852d6430, 0x0208b0f1f2941a30d3aec5525192848d3a7fd80de5edcaaae2a52c32d1221c1c);
const VK_Q4         = vkPoint(0x211ba95ae1ba7c0a36446d26b5ab7daa0e08af7f6759389ced3b0dc78637deb5, 0x0ecb810fc308c87bc230bf9ee9522d463299a733d5fa8635e79d8f81aef19b53);
const VK_QM         = vkPoint(0x2b7e3163c577a261d149aca4c8cac48eceaa209d28509c6507bcca007262c346, 0x2d5d4738519d792057a703e491e3c0ede0f1db9c334344469e5b626c2fd3bc69);
const VK_QC         = vkPoint(0x02b510f792e808fba6a0ad326433fe2b51442b4646e6374090ef3d0b007a6ffe, 0x0bf4dda853f62fdd4c5563b4307c2fb103b4540c5714f8fdb4b792470f05c1d8);
const VK_QARITH     = vkPoint(0x0167602bb66d7b5f9ceac16353050eae39211a91392f7e44435b55c90c6908c9, 0x0003758421e20fc1697b8b62bc01d1de94dc372053a63916b064e50f6474be7f);
const VK_QSORT      = vkPoint(0x2d10e96d7e399f05eeb5aa942674c4f21225094bc9a906dc137e5ccea1de2424, 0x1fce901ea1575e2b5bcc390b9de95fa8123a761452b9a4980f58e56c7c946c1b);
const VK_QELLIPTIC  = vkPoint(0x28b955aac4c043cbcfde06eee59b44363f96fe0a6fa93b0b36ef07fbe285d4c7, 0x16e1bbb0a7728dcb7696fdf3361b39510c6a4f83cc2159f5fc65ceb2be0599f9);
const VK_QAUX       = vkPoint(0x1414af76247139fa9e8fef8b393a3e03227ee3a6fedb1e55f5db82cb2352782a, 0x2c7895a68d2fab5b2bce4d7703daebf9011e63d675bc6898c7f06087d6d83d99);
const VK_SIGMA1     = vkPoint(0x107d126ead4dd71c906a8c04eb8f36e1a3dedb984937a818c908d47a1c7790da, 0x03d0f8ec676b2848262ab1c777843cc45284a1a353126da092ae3f391e64cc98);
const VK_SIGMA2     = vkPoint(0x0994ce55c05d3db9cd087919a4cac783ef373020433f078d9741fc6ae312c8ce, 0x0903a4f5944e9d1538218d59c09bd9741c177f8515150d0ac1a392d15d25265c);
const VK_SIGMA3     = vkPoint(0x01e3e835d07f92f851ce040245a81c1a3d2742b49f78d0f1b6437888e3a98df3, 0x2b08c280a12c3f9921abb231c66be512430c328ad5611b7d267f8605170980ec);
const VK_SIGMA4     = vkPoint(0x25aabd930c5d234698790db5b8efc3e094b07631fe690f3b04351871868073ec, 0x2918401ecc4d8a3bab010486bd569a0b2237eddfd820892269b752cd7fd0bb47);
const VK_TABLE1     = vkPoint(0x28faa42b5c13a5e9927d13e54a2ed806854cd23c6662b320439aa3168beffe03, 0x1e5c18afa66b4c0d19473e0536e64f678c1b094d1b2eff1d7f499dc289efc084);
const VK_TABLE2     = vkPoint(0x10a001251e9f3a9f283ff8f6bd14cba9c706f3c5040ec8ef10ff44988441251c, 0x12138fab93fce066ddb2f9be4eff97b0fe128a2a2c079f749b8452698cace8bf);
const VK_TABLE3     = vkPoint(0x133738f359ce2e0f909a0b76a78c602e66e39c41d99f65bfea25f47998283ccd, 0x2dd03593caea05125f520c0d02a3bbbdc5519822ba0e0b00984c5a9281143a81);
const VK_TABLE4     = vkPoint(0x09ec9b0aca4e9671903e0577f2a4efd36f7a58af0a5102f5a42e1b8061f62421, 0x15affeadf66c8428f4f44d2ebe66e9dc0f04215bef81efbbee166d3f4544feab);
const VK_TABLE_TYPE = vkPoint(0x1fd912d00da77afb70848e4442324157606f77f54ebc05d1a1a5fc2030836b13, 0x1b1c85cc22723d352d37c86cfd66d45e809a813b99a452fe452c7ae975de2286);
const VK_ID1        = vkPoint(0x02bd0a9d810b262e2c17785a234e36b82a165aa87df9ffd2b56620a71e9a2df7, 0x13fa30ba8301a879728e0b2d2734b311caaa46fad8f5d84684ae87db214fed16);
const VK_ID2        = vkPoint(0x2da92b415df7eb5c1b5885e8b1d6f256b388a4b5a124ea2cca16299373384a32, 0x1d249611ac6573d4b58b65f76bf959f0154f5a686cebc2c627f6efa744f7b02e);
const VK_ID3        = vkPoint(0x30542a7f3fac5fbfb71b10b6f26cfa5ff0cf3e06b9c374086b14e64cf0c6e571, 0x2271abecb362bb12ade1025b7446d60427125e985ab915334e930f6ff7d82d4c);
const VK_ID4        = vkPoint(0x115a17f256beca20398b4d682b6790807b81d96f8c300798edf990d3b702007b, 0x11d1df0a01befb70fb4ec3a782f5b1ffd708e6ce417c01689a7ec9eddce43115);

// G2 SRS point [x]_2 (for KZG pairing)
const VK_G2X: [128]u8 = vkG2(
    0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1, // X.c1
    0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0, // X.c0
    0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4, // Y.c1
    0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55, // Y.c0
);

// [1]_2 — standard BN254 G2 generator
const G2_GEN: [128]u8 = vkG2(
    0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
    0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed,
    0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
    0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa,
);

// G1 generator (1, 2)
const G1_GEN: G1P = blk: {
    var b = [_]u8{0} ** 64;
    b[31] = 1;  // x = 1
    b[63] = 2;  // y = 2
    break :blk b;
};

// ── Proof layout ───────────────────────────────────────────────────────────────

const FULL_LEN:    usize = 2240;
const PROOF_LEN:   usize = 2144;
const COMMIT_OFF:  usize = 0;
const EVAL_OFF:    usize = 11 * 64;   // 704
const OPEN_OFF:    usize = 11 * 64 + 41 * 32; // 2016

// Commitment indices (each 64 bytes)
const CI_W1:   usize = 0;
const CI_W2:   usize = 1;
const CI_W3:   usize = 2;
const CI_W4:   usize = 3;
const CI_S:    usize = 4;
const CI_Z:    usize = 5;
const CI_ZLKP: usize = 6;
const CI_T1:   usize = 7;
const CI_T2:   usize = 8;
const CI_T3:   usize = 9;
const CI_T4:   usize = 10;

// Evaluation indices (each 32 bytes, starting at EVAL_OFF)
const EI_W1:       usize = 0;
const EI_W2:       usize = 1;
const EI_W3:       usize = 2;
const EI_W4:       usize = 3;
const EI_S:        usize = 4;
const EI_Z:        usize = 5;
const EI_ZLKP:     usize = 6;
const EI_Q1:       usize = 7;
const EI_Q2:       usize = 8;
const EI_Q3:       usize = 9;
const EI_Q4:       usize = 10;
const EI_QM:       usize = 11;
const EI_QC:       usize = 12;
const EI_QARITH:   usize = 13;
const EI_QSORT:    usize = 14;
const EI_QELL:     usize = 15;
const EI_QAUX:     usize = 16;
const EI_SIGMA1:   usize = 17;
const EI_SIGMA2:   usize = 18;
const EI_SIGMA3:   usize = 19;
const EI_SIGMA4:   usize = 20;
const EI_TBL1:     usize = 21;
const EI_TBL2:     usize = 22;
const EI_TBL3:     usize = 23;
const EI_TBL4:     usize = 24;
const EI_TBLTYPE:  usize = 25;
const EI_ID1:      usize = 26;
const EI_ID2:      usize = 27;
const EI_ID3:      usize = 28;
const EI_ID4:      usize = 29;
const EI_W1W:      usize = 30;
const EI_W2W:      usize = 31;
const EI_W3W:      usize = 32;
const EI_W4W:      usize = 33;
const EI_SW:       usize = 34;
const EI_ZW:       usize = 35;
const EI_ZLKPW:    usize = 36;
const EI_TBL1W:    usize = 37;
const EI_TBL2W:    usize = 38;
const EI_TBL3W:    usize = 39;
const EI_TBL4W:    usize = 40;

// ── Fr field helpers ───────────────────────────────────────────────────────────

fn fk(comptime v: u256) fr.Fr {
    return fr.fromBytes32(&u256be(v));
}

fn frU64(v: u64) fr.Fr {
    var b = [_]u8{0} ** 32;
    std.mem.writeInt(u64, b[24..32], v, .big);
    return fr.fromBytes32(&b);
}

// Extract Fr element from proof slice at byte offset
fn fe(proof: []const u8, byte_offset: usize) fr.Fr {
    return fr.fromBytes32(proof[byte_offset..byte_offset + 32][0..32]);
}

// Convert Fr to raw [4]u64 limbs for scalarMul (from Montgomery form)
fn rawLimbs(a: fr.Fr) [4]u64 {
    return fr.mul(a, .{ 1, 0, 0, 0 });
}

// ── Evaluations struct ─────────────────────────────────────────────────────────

const Ev = struct {
    w1: fr.Fr, w2: fr.Fr, w3: fr.Fr, w4: fr.Fr,
    s: fr.Fr, z: fr.Fr, zlkp: fr.Fr,
    q1: fr.Fr, q2: fr.Fr, q3: fr.Fr, q4: fr.Fr,
    qm: fr.Fr, qc: fr.Fr, qar: fr.Fr, qso: fr.Fr,
    qel: fr.Fr, qau: fr.Fr,
    sig1: fr.Fr, sig2: fr.Fr, sig3: fr.Fr, sig4: fr.Fr,
    tbl1: fr.Fr, tbl2: fr.Fr, tbl3: fr.Fr, tbl4: fr.Fr,
    tblty: fr.Fr,
    id1: fr.Fr, id2: fr.Fr, id3: fr.Fr, id4: fr.Fr,
    w1w: fr.Fr, w2w: fr.Fr, w3w: fr.Fr, w4w: fr.Fr,
    sw: fr.Fr, zw: fr.Fr, zlkpw: fr.Fr,
    tbl1w: fr.Fr, tbl2w: fr.Fr, tbl3w: fr.Fr, tbl4w: fr.Fr,
};

fn loadEvals(proof: []const u8) Ev {
    const b = proof[EVAL_OFF..];
    return .{
        .w1   = fe(b, EI_W1*32),  .w2  = fe(b, EI_W2*32),   .w3   = fe(b, EI_W3*32),
        .w4   = fe(b, EI_W4*32),  .s   = fe(b, EI_S*32),    .z    = fe(b, EI_Z*32),
        .zlkp = fe(b, EI_ZLKP*32),
        .q1   = fe(b, EI_Q1*32),  .q2  = fe(b, EI_Q2*32),   .q3   = fe(b, EI_Q3*32),
        .q4   = fe(b, EI_Q4*32),  .qm  = fe(b, EI_QM*32),   .qc   = fe(b, EI_QC*32),
        .qar  = fe(b, EI_QARITH*32), .qso = fe(b, EI_QSORT*32),
        .qel  = fe(b, EI_QELL*32), .qau = fe(b, EI_QAUX*32),
        .sig1 = fe(b, EI_SIGMA1*32), .sig2 = fe(b, EI_SIGMA2*32),
        .sig3 = fe(b, EI_SIGMA3*32), .sig4 = fe(b, EI_SIGMA4*32),
        .tbl1 = fe(b, EI_TBL1*32), .tbl2 = fe(b, EI_TBL2*32),
        .tbl3 = fe(b, EI_TBL3*32), .tbl4 = fe(b, EI_TBL4*32),
        .tblty = fe(b, EI_TBLTYPE*32),
        .id1  = fe(b, EI_ID1*32), .id2 = fe(b, EI_ID2*32),
        .id3  = fe(b, EI_ID3*32), .id4 = fe(b, EI_ID4*32),
        .w1w  = fe(b, EI_W1W*32), .w2w = fe(b, EI_W2W*32),
        .w3w  = fe(b, EI_W3W*32), .w4w = fe(b, EI_W4W*32),
        .sw   = fe(b, EI_SW*32),  .zw  = fe(b, EI_ZW*32),
        .zlkpw = fe(b, EI_ZLKPW*32),
        .tbl1w = fe(b, EI_TBL1W*32), .tbl2w = fe(b, EI_TBL2W*32),
        .tbl3w = fe(b, EI_TBL3W*32), .tbl4w = fe(b, EI_TBL4W*32),
    };
}

// ── NU challenges ──────────────────────────────────────────────────────────────

const Nu = struct { v: [31]fr.Fr, raw30: [32]u8 };

fn nuChallenges(c_v0_raw: [32]u8) Nu {
    var r: Nu = undefined;
    r.v[0] = fr.fromBytes32(&c_v0_raw);
    var buf: [33]u8 = undefined;
    @memcpy(buf[0..32], &c_v0_raw);
    var i: u8 = 1;
    while (i <= 29) : (i += 1) {
        buf[32] = i;
        const raw = sdk.keccak256(&buf);
        r.v[i] = fr.fromBytes32(&raw);
        @memcpy(buf[0..32], &raw);
    }
    buf[32] = 0x1d;
    const raw30 = sdk.keccak256(&buf);
    r.v[30] = fr.fromBytes32(&raw30);
    r.raw30 = raw30;
    return r;
}

// ── Main verifier ──────────────────────────────────────────────────────────────

/// Verify a 2240-byte UltraPlonk proof for the state_anchor circuit.
/// Returns true if the proof is valid.
pub fn verifyStateAnchor(full_proof: []const u8) bool {
    if (full_proof.len < FULL_LEN) return false;

    const pub0 = full_proof[0..32];
    const pub1 = full_proof[32..64];
    const pub2 = full_proof[64..96];
    const proof = full_proof[96..96 + PROOF_LEN];

    // ── Round 0: initial challenge ────────────────────────────────────────────
    var init_buf: [8]u8 = undefined;
    std.mem.writeInt(u32, init_buf[0..4], @as(u32, VK_N), .big);
    std.mem.writeInt(u32, init_buf[4..8], VK_NUM_INPUTS, .big);
    const c0 = sdk.keccak256(&init_buf);

    // ── Round 1: ETA — keccak(c0 ‖ pub0 ‖ pub1 ‖ pub2 ‖ W1 ‖ W2 ‖ W3) ───────
    var eta_buf: [32 + 3*32 + 3*64]u8 = undefined;
    @memcpy(eta_buf[0..32], &c0);
    @memcpy(eta_buf[32..64], pub0);
    @memcpy(eta_buf[64..96], pub1);
    @memcpy(eta_buf[96..128], pub2);
    @memcpy(eta_buf[128..320], proof[0..192]); // W1(64)+W2(64)+W3(64)
    const c_eta = sdk.keccak256(&eta_buf);
    const eta   = fr.fromBytes32(&c_eta);
    const eta2  = fr.mul(eta, eta);
    const eta3  = fr.mul(eta2, eta);

    // ── Round 2: BETA — keccak(c_eta ‖ W4 ‖ S) ──────────────────────────────
    var beta_buf: [32 + 128]u8 = undefined;
    @memcpy(beta_buf[0..32], &c_eta);
    @memcpy(beta_buf[32..160], proof[192..320]); // W4(64)+S(64)
    const c_beta = sdk.keccak256(&beta_buf);
    const beta   = fr.fromBytes32(&c_beta);

    // ── Round 3: GAMMA — keccak(c_beta ‖ 0x01) ───────────────────────────────
    var gam_buf: [33]u8 = undefined;
    @memcpy(gam_buf[0..32], &c_beta);
    gam_buf[32] = 0x01;
    const c_gamma = sdk.keccak256(&gam_buf);
    const gamma   = fr.fromBytes32(&c_gamma);

    // ── Round 4: ALPHA — keccak(c_gamma ‖ Z ‖ Z_LKP) ────────────────────────
    var alp_buf: [32 + 128]u8 = undefined;
    @memcpy(alp_buf[0..32], &c_gamma);
    @memcpy(alp_buf[32..160], proof[320..448]); // Z(64)+Z_LKP(64)
    const c_alpha = sdk.keccak256(&alp_buf);
    const alpha   = fr.fromBytes32(&c_alpha);
    const alpha2  = fr.mul(alpha, alpha);
    const alpha3  = fr.mul(alpha2, alpha);
    const alpha4  = fr.mul(alpha3, alpha);

    // ── Round 5: ZETA — keccak(c_alpha ‖ T1 ‖ T2 ‖ T3 ‖ T4) ─────────────────
    var zeta_buf: [32 + 4*64]u8 = undefined;
    @memcpy(zeta_buf[0..32], &c_alpha);
    @memcpy(zeta_buf[32..288], proof[448..704]); // T1+T2+T3+T4
    const c_zeta = sdk.keccak256(&zeta_buf);
    const zeta   = fr.fromBytes32(&c_zeta);

    // ── Precomputed zeta powers ───────────────────────────────────────────────
    const zeta_n = frPowU64(zeta, VK_N);   // ζ^n

    // ── Lagrange / vanishing poly ─────────────────────────────────────────────
    // van_num = ζ^n - 1
    const van_num = fr.sub(zeta_n, fr.ONE);
    // van_denom = (ζ−ω_inv)(ζ−ω_inv²)(ζ−ω_inv³)(ζ−ω_inv⁴)
    const oi  = fk(VK_OMEGA_INV);
    const oi2 = fr.mul(oi, oi);
    const oi3 = fr.mul(oi2, oi);
    const oi4 = fr.mul(oi3, oi);
    const van_denom = fr.mul(fr.mul(fr.mul(
        fr.sub(zeta, oi),
        fr.sub(zeta, oi2)),
        fr.sub(zeta, oi3)),
        fr.sub(zeta, oi4)
    );
    // ZERO_POLY_INVERSE = van_denom / van_num
    const zp_inv = fr.mul(van_denom, fr.inv(van_num));

    // Lagrange polys: L_start(ζ) = van_num * domain_inv / (ζ - 1)
    //                L_end(ζ)   = van_num * domain_inv / (ω^5 * ζ - 1)
    const domain_inv = fk(VK_DOMAIN_INV);
    const lag_num    = fr.mul(van_num, domain_inv);
    const l_start    = fr.mul(lag_num, fr.inv(fr.sub(zeta, fr.ONE)));
    const omega      = fk(VK_OMEGA);
    const omega2     = fr.mul(omega, omega);
    const omega5     = fr.mul(fr.mul(omega2, omega2), omega);
    const l_end      = fr.mul(lag_num, fr.inv(fr.sub(fr.mul(omega5, zeta), fr.ONE)));

    // ── Public input delta ────────────────────────────────────────────────────
    const pi_delta = computePiDelta([3][]const u8{ pub0, pub1, pub2 }, beta, gamma, omega);

    // ── Plookup delta: [γ(1+β)]^{n−4} ────────────────────────────────────────
    const delta_base  = fr.mul(gamma, fr.add(beta, fr.ONE));
    const plkp_delta  = computePlookupDelta(delta_base);

    // ── Load evaluations ──────────────────────────────────────────────────────
    const ev = loadEvals(proof);

    // ── Gate widgets — alpha_base tracks accumulated alpha powers ─────────────
    var ab = alpha; // alpha_base starts at alpha

    // Permutation widget
    const perm_id = permutation(ev, alpha, beta, gamma, ab, pi_delta, l_start, l_end);
    ab = fr.mul(fr.mul(fr.mul(ab, alpha), alpha), alpha); // alpha^3

    // Plookup widget
    const plkp_id = plookup(ev, alpha, alpha2, beta, gamma, eta, eta2, eta3, ab, l_start, l_end, plkp_delta);
    ab = fr.mul(fr.mul(fr.mul(ab, alpha), alpha), alpha); // alpha^3

    // Arithmetic widget
    const arith_id = arithmetic(ev, alpha, ab);
    ab = fr.mul(fr.mul(ab, alpha), alpha); // alpha^2

    // Sort widget
    const sort_id = sort(ev, alpha, alpha2, alpha3, alpha4, ab);
    ab = fr.mul(fr.mul(fr.mul(fr.mul(ab, alpha), alpha), alpha), alpha); // alpha^4

    // Elliptic widget
    const ell_id = elliptic(ev, alpha, ab);
    ab = fr.mul(fr.mul(fr.mul(fr.mul(ab, alpha), alpha), alpha), alpha); // alpha^4

    // Auxiliary widget
    const aux_id = auxiliary(ev, alpha, alpha3, ab, eta);
    // ab *= alpha^3 (not needed after aux)

    // ── Quotient evaluation ───────────────────────────────────────────────────
    const quot_eval = fr.mul(
        fr.add(fr.add(fr.add(fr.add(fr.add(perm_id, plkp_id), arith_id), sort_id), ell_id), aux_id),
        zp_inv
    );

    // ── NU challenges — keccak(c_zeta ‖ quot_eval ‖ 41 evals) ───────────────
    var nu_buf: [32 + 32 + 41*32]u8 = undefined;
    @memcpy(nu_buf[0..32], &c_zeta);
    var quot_bytes: [32]u8 = undefined;
    fr.toBytes32(quot_eval, &quot_bytes);
    @memcpy(nu_buf[32..64], &quot_bytes);
    @memcpy(nu_buf[64..], proof[EVAL_OFF..EVAL_OFF + 41*32]);
    const c_v0_raw = sdk.keccak256(&nu_buf);
    const nu = nuChallenges(c_v0_raw);

    // ── U challenge — keccak(c_v30 ‖ PI_Z ‖ PI_Z_OMEGA) ─────────────────────
    const piz    = proof[OPEN_OFF..OPEN_OFF+64];
    const pizom  = proof[OPEN_OFF+64..OPEN_OFF+128];
    var u_buf: [32 + 128]u8 = undefined;
    @memcpy(u_buf[0..32], &nu.raw30);
    @memcpy(u_buf[32..96],  piz);
    @memcpy(u_buf[96..160], pizom);
    const c_u = sdk.keccak256(&u_buf);
    const u   = fr.fromBytes32(&c_u);

    // ── Batch commitment accumulator ──────────────────────────────────────────
    // Step 1: T1 + T2·ζ^n + T3·ζ^{2n} + T4·ζ^{3n}
    const zn2 = fr.mul(zeta_n, zeta_n);
    const zn3 = fr.mul(zn2, zeta_n);
    var acc = loadG1(proof, CI_T1)
        .addJac(loadG1(proof, CI_T2).scalarMul(rawLimbs(zeta_n)))
        .addJac(loadG1(proof, CI_T3).scalarMul(rawLimbs(zn2)))
        .addJac(loadG1(proof, CI_T4).scalarMul(rawLimbs(zn3)));

    // Step 2: (u+1)·vᵢ for proof commitments W1..Z_LKP
    const up1 = fr.add(u, fr.ONE);
    const up1v = [7]fr.Fr{
        fr.mul(up1, nu.v[0]), fr.mul(up1, nu.v[1]), fr.mul(up1, nu.v[2]),
        fr.mul(up1, nu.v[3]), fr.mul(up1, nu.v[4]), fr.mul(up1, nu.v[5]),
        fr.mul(up1, nu.v[6]),
    };
    const proof_commits = [7]usize{ CI_W1, CI_W2, CI_W3, CI_W4, CI_S, CI_Z, CI_ZLKP };
    for (0..7) |i| {
        acc = acc.addJac(loadG1(proof, proof_commits[i]).scalarMul(rawLimbs(up1v[i])));
    }

    // Step 3: vⱼ for VK fixed points (v7..v30)
    const vk_pts = [23]G1P{
        VK_Q1, VK_Q2, VK_Q3, VK_Q4, VK_QM, VK_QC, VK_QARITH, VK_QSORT,
        VK_QELLIPTIC, VK_QAUX,
        VK_SIGMA1, VK_SIGMA2, VK_SIGMA3, VK_SIGMA4,
        VK_TABLE1, VK_TABLE2, VK_TABLE3, VK_TABLE4, VK_TABLE_TYPE,
        VK_ID1, VK_ID2, VK_ID3, VK_ID4,
    };
    for (0..23) |i| {
        acc = acc.addJac(G1.fromAffineBytes(&vk_pts[i]).scalarMul(rawLimbs(nu.v[7 + i])));
    }

    // Step 4: subtract [1]·batch_eval
    const batch_ev = batchEval(ev, nu, u, quot_eval);
    acc = acc.addJac(G1.fromAffineBytes(&G1_GEN).scalarMul(rawLimbs(batch_ev)).neg());

    // This is PAIRING_RHS (before adding PI_Z·ζ + PI_Z_OMEGA·u·ζ·ω)
    const PI_Z_pt   = G1.fromAffineBytes(piz[0..64]);
    const PI_ZW_pt  = G1.fromAffineBytes(pizom[0..64]);
    const u_zeta_om = fr.mul(fr.mul(u, zeta), omega);
    acc = acc.addJac(PI_Z_pt.scalarMul(rawLimbs(zeta)));
    acc = acc.addJac(PI_ZW_pt.scalarMul(rawLimbs(u_zeta_om)));
    // acc = PAIRING_RHS

    // PAIRING_LHS = -(PI_Z + u·PI_ZW) (negated for pairing check)
    var lhs = PI_Z_pt.addJac(PI_ZW_pt.scalarMul(rawLimbs(u))).neg();

    // ── Final KZG pairing: e(PAIRING_RHS, [1]_2) · e(PAIRING_LHS, [x]_2) == 1 ─
    var rhs_bytes: [64]u8 = undefined;
    var lhs_bytes: [64]u8 = undefined;
    acc.toAffineBytes(&rhs_bytes);
    lhs.toAffineBytes(&lhs_bytes);

    var pair_in: [2 * 192]u8 = undefined;
    @memcpy(pair_in[0..64],    &rhs_bytes);
    @memcpy(pair_in[64..192],  &G2_GEN);
    @memcpy(pair_in[192..256], &lhs_bytes);
    @memcpy(pair_in[256..384], &VK_G2X);

    const EC_PAIRING: [20]u8 = Stylus.ADDR_ECPAIRING;
    var ret_len: u32 = 0;
    const st = vm.static_call_contract(&EC_PAIRING, &pair_in, 384, 800_000, &ret_len);
    if (st != 0 or ret_len < 32) return false;
    var ret: [32]u8 = undefined;
    _ = vm.read_return_data(&ret, 0, 32);
    return ret[31] == 1;
}

// ── Gate widgets ───────────────────────────────────────────────────────────────

fn permutation(
    ev: Ev,
    alpha: fr.Fr, beta: fr.Fr, gamma: fr.Fr,
    ab: fr.Fr, pi_delta: fr.Fr, l_start: fr.Fr, l_end: fr.Fr,
) fr.Fr {
    // (w1+γ+β·id1)(w2+γ+β·id2)(w3+γ+β·id3)(w4+γ+β·id4)·Z·ab
    const t1 = fr.mul(
        fr.add(fr.add(ev.w1, gamma), fr.mul(beta, ev.id1)),
        fr.add(fr.add(ev.w2, gamma), fr.mul(beta, ev.id2)),
    );
    const t2 = fr.mul(
        fr.add(fr.add(ev.w3, gamma), fr.mul(beta, ev.id3)),
        fr.add(fr.add(ev.w4, gamma), fr.mul(beta, ev.id4)),
    );
    var res = fr.mul(ab, fr.mul(ev.z, fr.mul(t1, t2)));

    // − (w1+γ+β·σ1)..·Zω·ab
    const t1b = fr.mul(
        fr.add(fr.add(ev.w1, gamma), fr.mul(beta, ev.sig1)),
        fr.add(fr.add(ev.w2, gamma), fr.mul(beta, ev.sig2)),
    );
    const t2b = fr.mul(
        fr.add(fr.add(ev.w3, gamma), fr.mul(beta, ev.sig3)),
        fr.add(fr.add(ev.w4, gamma), fr.mul(beta, ev.sig4)),
    );
    res = fr.sub(res, fr.mul(ab, fr.mul(ev.zw, fr.mul(t1b, t2b))));

    // ab·α · L_end(ζ) · (Zω − ΔPI)
    const ab_a = fr.mul(ab, alpha);
    res = fr.add(res, fr.mul(ab_a, fr.mul(l_end, fr.sub(ev.zw, pi_delta))));

    // ab·α² · L_start(ζ) · (Z − 1)
    const ab_a2 = fr.mul(ab_a, alpha);
    res = fr.add(res, fr.mul(ab_a2, fr.mul(l_start, fr.sub(ev.z, fr.ONE))));

    return res;
}

fn plookup(
    ev: Ev,
    alpha: fr.Fr, alpha2: fr.Fr,
    beta: fr.Fr, gamma: fr.Fr,
    eta: fr.Fr, eta2: fr.Fr, eta3: fr.Fr,
    ab: fr.Fr, l_start: fr.Fr, l_end: fr.Fr, plkp_delta: fr.Fr,
) fr.Fr {
    _ = alpha;
    // f = η·q3 + (w3+qc·w3w); f = f·η + (w2+qm·w2w); f = f·η + (w1+q2·w1w)
    var f = fr.mul(eta, ev.q3);
    f = fr.add(f, fr.add(ev.w3, fr.mul(ev.qc, ev.w3w)));
    f = fr.mul(f, eta);
    f = fr.add(f, fr.add(ev.w2, fr.mul(ev.qm, ev.w2w)));
    f = fr.mul(f, eta);
    f = fr.add(f, fr.add(ev.w1, fr.mul(ev.q2, ev.w1w)));

    // t(ζ) = tbl4·η³ + tbl3·η² + tbl2·η + tbl1
    const t  = fr.add(fr.add(fr.add(fr.mul(ev.tbl4, eta3), fr.mul(ev.tbl3, eta2)), fr.mul(ev.tbl2, eta)), ev.tbl1);
    const tw = fr.add(fr.add(fr.add(fr.mul(ev.tbl4w, eta3), fr.mul(ev.tbl3w, eta2)), fr.mul(ev.tbl2w, eta)), ev.tbl1w);

    const gam_beta = fr.mul(gamma, fr.add(beta, fr.ONE));
    var num = fr.add(fr.mul(f, ev.tblty), gamma);
    num = fr.mul(num, fr.add(fr.add(t, fr.mul(tw, beta)), gam_beta));
    num = fr.mul(num, fr.add(beta, fr.ONE));
    const tmp = fr.mul(alpha2, l_start);
    num = fr.add(num, tmp);
    num = fr.mul(num, ev.zlkp);
    num = fr.sub(num, tmp);

    var den = fr.add(fr.add(ev.s, fr.mul(ev.sw, beta)), gam_beta);
    const tmp2 = fr.mul(alpha2, l_end);
    den = fr.sub(den, tmp2);
    den = fr.mul(den, ev.zlkpw);
    den = fr.add(den, fr.mul(tmp2, plkp_delta));

    return fr.mul(fr.sub(num, den), ab);
}

fn arithmetic(ev: Ev, alpha: fr.Fr, ab: fr.Fr) fr.Fr {
    const NEG_INV2 = comptime fk(0x183227397098d014dc2822db40c0ac2e9419f4243cdcb848a1f0fac9f8000000);
    const w1w2qm = fr.mul(
        fr.mul(fr.mul(fr.mul(ev.w1, ev.w2), ev.qm), fr.sub(ev.qar, frU64(3))),
        NEG_INV2
    );
    const id = fr.add(ev.qc, fr.add(
        fr.mul(ev.w4, ev.q4),
        fr.add(fr.mul(ev.w3, ev.q3), fr.add(fr.mul(ev.w2, ev.q2), fr.add(fr.mul(ev.w1, ev.q1), w1w2qm)))
    ));
    const mini = fr.mul(alpha, fr.mul(
        fr.sub(ev.qar, frU64(2)),
        fr.add(ev.qm, fr.sub(fr.add(ev.w1, ev.w4), ev.w1w))
    ));
    return fr.mul(ab, fr.mul(ev.qar, fr.add(
        id, fr.mul(fr.sub(ev.qar, fr.ONE), fr.add(ev.w4w, mini))
    )));
}

fn sortTerm(d: fr.Fr) fr.Fr {
    return fr.mul(fr.mul(fr.sub(fr.mul(d, d), d), fr.sub(d, frU64(2))), fr.sub(d, frU64(3)));
}

fn sort(ev: Ev, alpha: fr.Fr, alpha2: fr.Fr, alpha3: fr.Fr, alpha4: fr.Fr, ab: fr.Fr) fr.Fr {
    _ = alpha4;
    const d1 = fr.sub(ev.w2, ev.w1);
    const d2 = fr.sub(ev.w3, ev.w2);
    const d3 = fr.sub(ev.w4, ev.w3);
    const d4 = fr.sub(ev.w1w, ev.w4);
    var acc = fr.mul(sortTerm(d1), ab);
    acc = fr.add(acc, fr.mul(sortTerm(d2), fr.mul(ab, alpha)));
    acc = fr.add(acc, fr.mul(sortTerm(d3), fr.mul(ab, alpha2)));
    acc = fr.add(acc, fr.mul(sortTerm(d4), fr.mul(ab, alpha3)));
    return fr.mul(acc, ev.qso);
}

fn elliptic(ev: Ev, alpha: fr.Fr, ab: fr.Fr) fr.Fr {
    // Aliases: X1=w2, X2=w1w, X3=w2w, Y1=w3, Y2=w4w, Y3=w3w, qsign=q1
    const x1 = ev.w2; const x2 = ev.w1w; const x3 = ev.w2w;
    const y1 = ev.w3; const y2 = ev.w4w; const y3 = ev.w3w;
    const qsign = ev.q1;

    // Add identity
    const xd = fr.sub(x2, x1);
    const y1y2 = fr.mul(fr.mul(y1, y2), qsign);
    var x_add = fr.add(
        fr.mul(fr.add(x3, fr.add(x2, x1)), fr.mul(xd, xd)),
        fr.sub(fr.add(y1y2, y1y2), fr.add(fr.mul(y2,y2), fr.mul(y1,y1)))
    );
    x_add = fr.mul(fr.mul(x_add, fr.sub(fr.ONE, ev.qm)), ab);

    const y1y3 = fr.add(y1, y3);
    const yd = fr.sub(fr.mul(y2, qsign), y1);
    var y_add = fr.add(fr.mul(y1y3, xd), fr.mul(fr.sub(x3, x1), yd));
    y_add = fr.mul(fr.mul(y_add, fr.sub(fr.ONE, ev.qm)), fr.mul(ab, alpha));

    const add_id = fr.mul(fr.add(x_add, y_add), ev.qel);

    // Double identity
    const x1s = fr.mul(x1, x1);
    const y1s = fr.mul(y1, y1);
    const xp4 = fr.mul(fr.add(y1s, frU64(17)), x1); // b=3 on BN254, Grumpkin b=-17 negated
    const x_dbl = fr.sub(fr.mul(fr.add(x3, fr.add(x1,x1)), fr.mul(y1s, frU64(4))), fr.mul(xp4, frU64(9)));
    const y_dbl = fr.sub(
        fr.mul(fr.mul(x1s, frU64(3)), fr.sub(x1, x3)),
        fr.mul(fr.add(y1,y1), fr.add(y1,y3))
    );
    const dbl_id = fr.mul(fr.add(
        fr.mul(fr.mul(x_dbl, ab), ev.qm),
        fr.mul(fr.mul(y_dbl, fr.mul(ab, alpha)), ev.qm)
    ), ev.qel);

    return fr.add(add_id, dbl_id);
}

fn auxiliary(ev: Ev, alpha: fr.Fr, alpha3: fr.Fr, ab: fr.Fr, eta: fr.Fr) fr.Fr {
    _ = alpha3;
    const LIMB: fr.Fr = comptime fk(0x0000000000000000000000000000000100000000000000000); // 2^68
    const SUBS: fr.Fr = comptime fk(0x4000); // 2^14

    // Non-native field gate
    var lsub = fr.add(fr.mul(ev.w1, ev.w2w), fr.mul(ev.w1w, ev.w2));
    var g2 = fr.sub(fr.add(fr.mul(ev.w1, ev.w4), fr.mul(ev.w2, ev.w3)), ev.w3w);
    g2 = fr.add(fr.sub(fr.add(fr.mul(g2, LIMB), fr.neg(ev.w4w)), lsub), lsub); // wait, need to recalculate
    g2 = fr.mul(fr.sub(fr.add(fr.mul(fr.sub(fr.add(fr.mul(ev.w1,ev.w4),fr.mul(ev.w2,ev.w3)),ev.w3w), LIMB), ev.w4w), fr.neg(lsub)), ev.q4);
    // Fix: g2 = ((w1*w4+w2*w3-w3w)*LIMB - w4w + lsub) * q4
    g2 = fr.mul(
        fr.add(fr.sub(fr.mul(fr.sub(fr.add(fr.mul(ev.w1,ev.w4),fr.mul(ev.w2,ev.w3)),ev.w3w), LIMB), ev.w4w), lsub),
        ev.q4
    );
    lsub = fr.mul(lsub, LIMB);
    lsub = fr.add(lsub, fr.mul(ev.w1w, ev.w2w));
    const g1d = fr.mul(fr.sub(lsub, fr.add(ev.w3, ev.w4)), ev.q3);
    const g3d = fr.mul(fr.sub(fr.add(lsub, ev.w4), fr.add(ev.w3w, ev.w4w)), ev.qm);
    const nnf = fr.mul(fr.add(fr.add(g1d, g2), g3d), ev.q2);

    // Limb accumulator
    var la1 = fr.mul(ev.w2w, SUBS);
    la1 = fr.add(la1, ev.w1w);
    la1 = fr.mul(la1, SUBS);
    la1 = fr.add(la1, ev.w3);
    la1 = fr.mul(la1, SUBS);
    la1 = fr.add(la1, ev.w2);
    la1 = fr.mul(la1, SUBS);
    la1 = fr.sub(fr.add(la1, ev.w1), ev.w4);
    la1 = fr.mul(la1, ev.q4);

    var la2 = fr.mul(ev.w3w, SUBS);
    la2 = fr.add(la2, ev.w2w);
    la2 = fr.mul(la2, SUBS);
    la2 = fr.add(la2, ev.w1w);
    la2 = fr.mul(la2, SUBS);
    la2 = fr.add(la2, ev.w4);
    la2 = fr.mul(la2, SUBS);
    la2 = fr.sub(fr.add(la2, ev.w3), ev.w4w);
    la2 = fr.mul(la2, ev.qm);
    const la = fr.mul(fr.add(la1, la2), ev.q3);

    // Memory checks
    var mrec = fr.mul(ev.w3, eta);
    mrec = fr.add(mrec, ev.w2);
    mrec = fr.mul(mrec, eta);
    mrec = fr.add(mrec, ev.w1);
    mrec = fr.mul(mrec, eta);
    mrec = fr.add(mrec, ev.qc);
    const prec = mrec;
    mrec = fr.sub(mrec, ev.w4);

    const id_delta = fr.sub(ev.w1w, ev.w1);
    const rv_delta = fr.sub(ev.w4w, ev.w4);
    const id_mono  = fr.mul(id_delta, fr.sub(id_delta, fr.ONE));
    const adj_rom  = fr.mul(rv_delta, fr.sub(fr.ONE, id_delta));
    const rom_cci  = fr.add(fr.mul(fr.add(fr.mul(adj_rom, alpha), id_mono), alpha), mrec);

    var ng = fr.mul(ev.w3w, eta);
    ng = fr.add(ng, ev.w2w);
    ng = fr.mul(ng, eta);
    ng = fr.add(ng, ev.w1w);
    ng = fr.mul(ng, eta);
    ng = fr.sub(ev.w4w, ng);

    const vd = fr.sub(ev.w3w, ev.w3);
    const adj_ram = fr.mul(fr.sub(fr.ONE, id_delta), fr.mul(vd, fr.sub(fr.ONE, ng)));
    const at = fr.sub(ev.w4, prec);
    const ac = fr.mul(at, fr.sub(at, fr.ONE));
    const ngb = fr.mul(ng, fr.sub(ng, fr.ONE));
    var ram_cci = fr.mul(adj_ram, alpha);
    ram_cci = fr.add(ram_cci, id_mono);
    ram_cci = fr.mul(ram_cci, alpha);
    ram_cci = fr.add(ram_cci, ngb);
    ram_cci = fr.mul(ram_cci, alpha);
    ram_cci = fr.add(ram_cci, ac);

    const tsd = fr.sub(ev.w2w, ev.w2);
    const ram_ts = fr.sub(fr.mul(tsd, fr.sub(fr.ONE, id_delta)), ev.w3);

    var mem = fr.mul(rom_cci, ev.q2);
    mem = fr.add(mem, fr.mul(ram_ts, ev.q4));
    mem = fr.add(mem, fr.mul(mrec, ev.qm));
    mem = fr.mul(mem, ev.q1);
    mem = fr.add(mem, fr.mul(ram_cci, ev.qar));

    return fr.mul(fr.mul(fr.add(fr.add(mem, nnf), la), ev.qau), ab);
}

// ── Batch evaluation scalar ────────────────────────────────────────────────────

fn batchEval(ev: Ev, nu: Nu, u: fr.Fr, quot: fr.Fr) fr.Fr {
    var b = fr.mul(nu.v[0], fr.add(ev.w1, fr.mul(u, ev.w1w)));
    b = fr.add(b, fr.mul(nu.v[1], fr.add(ev.w2, fr.mul(u, ev.w2w))));
    b = fr.add(b, fr.mul(nu.v[2], fr.add(ev.w3, fr.mul(u, ev.w3w))));
    b = fr.add(b, fr.mul(nu.v[3], fr.add(ev.w4, fr.mul(u, ev.w4w))));
    b = fr.add(b, fr.mul(nu.v[4], fr.add(ev.s,  fr.mul(u, ev.sw))));
    b = fr.add(b, fr.mul(nu.v[5], fr.add(ev.z,  fr.mul(u, ev.zw))));
    b = fr.add(b, fr.mul(nu.v[6], fr.add(ev.zlkp, fr.mul(u, ev.zlkpw))));
    b = fr.add(b, fr.mul(nu.v[7],  ev.q1));
    b = fr.add(b, fr.mul(nu.v[8],  ev.q2));
    b = fr.add(b, fr.mul(nu.v[9],  ev.q3));
    b = fr.add(b, fr.mul(nu.v[10], ev.q4));
    b = fr.add(b, fr.mul(nu.v[11], ev.qm));
    b = fr.add(b, fr.mul(nu.v[12], ev.qc));
    b = fr.add(b, fr.mul(nu.v[13], ev.qar));
    b = fr.add(b, fr.mul(nu.v[14], ev.qso));
    b = fr.add(b, fr.mul(nu.v[15], ev.qel));
    b = fr.add(b, fr.mul(nu.v[16], ev.qau));
    b = fr.add(b, fr.mul(nu.v[17], ev.sig1));
    b = fr.add(b, fr.mul(nu.v[18], ev.sig2));
    b = fr.add(b, fr.mul(nu.v[19], ev.sig3));
    b = fr.add(b, fr.mul(nu.v[20], ev.sig4));
    b = fr.add(b, fr.mul(nu.v[21], fr.add(ev.tbl1, fr.mul(u, ev.tbl1w))));
    b = fr.add(b, fr.mul(nu.v[22], fr.add(ev.tbl2, fr.mul(u, ev.tbl2w))));
    b = fr.add(b, fr.mul(nu.v[23], fr.add(ev.tbl3, fr.mul(u, ev.tbl3w))));
    b = fr.add(b, fr.mul(nu.v[24], fr.add(ev.tbl4, fr.mul(u, ev.tbl4w))));
    b = fr.add(b, fr.mul(nu.v[25], ev.tblty));
    b = fr.add(b, fr.mul(nu.v[26], ev.id1));
    b = fr.add(b, fr.mul(nu.v[27], ev.id2));
    b = fr.add(b, fr.mul(nu.v[28], ev.id3));
    b = fr.add(b, fr.mul(nu.v[29], ev.id4));
    b = fr.add(b, quot);
    return b;
}

// ── Public input delta ─────────────────────────────────────────────────────────

fn computePiDelta(pubs: [3][]const u8, beta: fr.Fr, gamma: fr.Fr, omega: fr.Fr) fr.Fr {
    var num: fr.Fr = fr.ONE;
    var den: fr.Fr = fr.ONE;
    var r1 = fr.mul(beta, frU64(0x05));
    var r2 = fr.mul(beta, frU64(0x0c));
    for (pubs) |pi| {
        const inp = fr.fromBytes32(pi[0..32]);
        const g   = gamma;
        num = fr.mul(num, fr.add(fr.add(inp, g), r1));
        den = fr.mul(den, fr.add(fr.add(inp, g), r2));
        r1 = fr.mul(r1, omega);
        r2 = fr.mul(r2, omega);
    }
    return fr.mul(num, fr.inv(den));
}

// ── Plookup delta: [γ(1+β)]^{n−4} ────────────────────────────────────────────

fn computePlookupDelta(delta_base: fr.Fr) fr.Fr {
    // delta_n = delta_base^n via repeated squaring (n = VK_N = 2^17)
    var delta_n = delta_base;
    var count: u64 = 1;
    while (count < VK_N) : (count += count) {
        delta_n = fr.mul(delta_n, delta_n);
    }
    // delta_denom = delta_base^4
    const d2 = fr.mul(delta_base, delta_base);
    const d4 = fr.mul(d2, d2);
    return fr.mul(delta_n, fr.inv(d4));
}

// ── Misc helpers ───────────────────────────────────────────────────────────────

fn loadG1(proof: []const u8, idx: usize) G1 {
    return G1.fromAffineBytes(proof[idx*64..idx*64+64][0..64]);
}

fn frPowU64(base: fr.Fr, exp: u64) fr.Fr {
    var r = fr.ONE;
    var b = base;
    var e = exp;
    while (e > 0) : (e >>= 1) {
        if (e & 1 != 0) r = fr.mul(r, b);
        b = fr.mul(b, b);
    }
    return r;
}

// ── Comptime helpers ───────────────────────────────────────────────────────────

fn u256be(comptime v: u256) [32]u8 {
    var b: [32]u8 = undefined;
    var rem = v;
    var i: usize = 32;
    while (i > 0) {
        i -= 1;
        b[i] = @truncate(rem & 0xff);
        rem >>= 8;
    }
    return b;
}

fn vkPoint(comptime x: u256, comptime y: u256) G1P {
    var b: G1P = undefined;
    @memcpy(b[0..32], &u256be(x));
    @memcpy(b[32..64], &u256be(y));
    return b;
}

fn vkG2(comptime x1: u256, comptime x0: u256, comptime y1: u256, comptime y0: u256) [128]u8 {
    var b: [128]u8 = undefined;
    @memcpy(b[0..32],   &u256be(x1));
    @memcpy(b[32..64],  &u256be(x0));
    @memcpy(b[64..96],  &u256be(y1));
    @memcpy(b[96..128], &u256be(y0));
    return b;
}
