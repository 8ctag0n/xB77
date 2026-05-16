//! Tests for core/onchain/* modules.
//!
//! Covers:
//!   1. wincode.Writer/Reader roundtrip with primitives.
//!   2. wincode 125-byte VerifyTransition fixture.
//!   3. IdlClient encodes VerifyTransition to 125 bytes from the real IDL JSON.
//!   4. solana_tx.buildLegacyTx produces a well-formed single-signer tx.
//!   5. Ed25519 sign + verify roundtrip on a built tx.

const std = @import("std");
const core = @import("core");

const wincode = core.onchain.wincode;
const idl_client_mod = core.onchain.idl_client;
const solana_tx = core.onchain.solana_tx;
const crypto_mod = core.crypto;

const IdlClient = idl_client_mod.IdlClient;
const FieldValue = idl_client_mod.FieldValue;
const NamedField = idl_client_mod.NamedField;

// ── wincode tests ─────────────────────────────────────────────────────────

test "wincode: primitives roundtrip" {
    const allocator = std.testing.allocator;

    var w = wincode.Writer.init();
    defer w.deinit(allocator);

    try w.u8W(allocator, 255);
    try w.i8W(allocator, -128);
    try w.u16W(allocator, 0xABCD);
    try w.u32W(allocator, 0xDEADBEEF);
    try w.u64W(allocator, 0x01_02_03_04_05_06_07_08);
    try w.boolW(allocator, true);
    try w.boolW(allocator, false);

    var r = wincode.Reader.init(w.bytes());
    try std.testing.expectEqual(@as(u8, 255), try r.u8R());
    try std.testing.expectEqual(@as(i8, -128), try r.i8R());
    try std.testing.expectEqual(@as(u16, 0xABCD), try r.u16R());
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try r.u32R());
    try std.testing.expectEqual(@as(u64, 0x01_02_03_04_05_06_07_08), try r.u64R());
    try std.testing.expect(try r.boolR());
    try std.testing.expect(!(try r.boolR()));
    try std.testing.expect(r.eof());
}

test "wincode: 125-byte VerifyTransition fixture" {
    const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

    var new_root: [32]u8 = undefined;
    var idx: usize = 0;
    while (idx < 32) : (idx += 1) {
        new_root[idx] = try std.fmt.parseInt(u8, NEW_ROOT_HEX[idx * 2 .. idx * 2 + 2], 16);
    }

    const allocator = std.testing.allocator;

    var w = wincode.Writer.init();
    defer w.deinit(allocator);

    // disc u32 LE = 0
    try w.enumTag(allocator, 0);
    // old_root [u8; 32]
    try w.fixed(allocator, &([_]u8{0} ** 32));
    // new_root [u8; 32]
    try w.fixed(allocator, &new_root);
    // index u64 = 0
    try w.u64W(allocator, 0);
    // siblings len u64 = 0
    try w.u64W(allocator, 0);
    // amount u64 = 1
    try w.u64W(allocator, 1);
    // type u8 = 0
    try w.u8W(allocator, 0);
    // tx_hash [u8; 32]
    try w.fixed(allocator, &([_]u8{0} ** 32));

    try std.testing.expectEqual(@as(usize, 125), w.bytes().len);

    // new_root at offset 36 (disc=4, old_root=32)
    try std.testing.expectEqualSlices(u8, &new_root, w.bytes()[36..68]);

    // amount at offset 84 (4+32+32+8+8 = 84): should be 0x01 followed by zeros
    try std.testing.expectEqual(@as(u8, 1), w.bytes()[84]);
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[85]);
}

// ── IDL client tests ──────────────────────────────────────────────────────

test "idl_client: encodeInstruction VerifyTransition → 125 bytes" {
    const allocator = std.testing.allocator;

    const idl_json = try std.fs.cwd().readFileAlloc(allocator, "idls/xb77.iopression.json", 64 * 1024);
    defer allocator.free(idl_json);

    var client = try IdlClient.init(allocator, idl_json);
    defer client.deinit();

    const disc = try client.discriminantOf("VerifyTransition");
    try std.testing.expectEqual(@as(u32, 0), disc);

    const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";
    var new_root: [32]u8 = undefined;
    var idx: usize = 0;
    while (idx < 32) : (idx += 1) {
        new_root[idx] = try std.fmt.parseInt(u8, NEW_ROOT_HEX[idx * 2 .. idx * 2 + 2], 16);
    }

    const old_root = [_]u8{0} ** 32;
    const tx_hash = [_]u8{0} ** 32;
    const siblings = [0][32]u8{};

    const payload_fields = [_]NamedField{
        .{ .name = "old_root",              .value = .{ .bytes = &old_root } },
        .{ .name = "new_root",              .value = .{ .bytes = &new_root } },
        .{ .name = "index",                 .value = .{ .u64_val = 0 } },
        .{ .name = "siblings",              .value = .{ .vec_fixed32 = &siblings } },
        .{ .name = "leaf_preimage_amount",  .value = .{ .u64_val = 1 } },
        .{ .name = "leaf_preimage_type",    .value = .{ .u8_val = 0 } },
        .{ .name = "leaf_preimage_tx_hash", .value = .{ .bytes = &tx_hash } },
    };
    const top_fields = [_]NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };

    const data = try client.encodeInstruction("VerifyTransition", &top_fields);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 125), data.len);

    // discriminant bytes
    try std.testing.expectEqual(@as(u8, 0), data[0]);
    try std.testing.expectEqual(@as(u8, 0), data[1]);
    try std.testing.expectEqual(@as(u8, 0), data[2]);
    try std.testing.expectEqual(@as(u8, 0), data[3]);

    // new_root at offset 36
    try std.testing.expectEqualSlices(u8, &new_root, data[36..68]);
}

// ── solana_tx tests ───────────────────────────────────────────────────────

test "solana_tx: buildLegacyTx structure" {
    const allocator = std.testing.allocator;

    const payer = crypto_mod.generateKeypair();
    var prog: [32]u8 = undefined;
    std.crypto.random.bytes(&prog);
    var bh: [32]u8 = undefined;
    std.crypto.random.bytes(&bh);

    const data = [_]u8{ 0xAA, 0xBB };
    const ix = solana_tx.Instruction{
        .program_id = prog,
        .accounts = &.{},
        .data = &data,
    };

    const tx = try solana_tx.buildLegacyTx(allocator, &payer.public, &bh, &[_]solana_tx.Instruction{ix});
    defer allocator.free(tx);

    // Byte 0: compact-u16(1) = 0x01
    try std.testing.expectEqual(@as(u8, 0x01), tx[0]);
    // Bytes 1..64: zero placeholder for signature
    for (tx[1..65]) |b| try std.testing.expectEqual(@as(u8, 0), b);
    // Byte 65: header.num_required_sigs = 1
    try std.testing.expectEqual(@as(u8, 1), tx[65]);
}

test "solana_tx: sign + Ed25519 verify" {
    const allocator = std.testing.allocator;

    const kp = crypto_mod.generateKeypair();
    var prog: [32]u8 = undefined;
    std.crypto.random.bytes(&prog);
    var bh: [32]u8 = undefined;
    std.crypto.random.bytes(&bh);

    const data = [_]u8{ 1, 2, 3 };
    const ix = solana_tx.Instruction{
        .program_id = prog,
        .accounts = &.{},
        .data = &data,
    };

    const tx = try solana_tx.buildLegacyTx(allocator, &kp.public, &bh, &[_]solana_tx.Instruction{ix});
    defer allocator.free(tx);

    solana_tx.signTx(tx, &kp);

    // Verify the signature manually.
    const sig_bytes = tx[1..65];
    const message = tx[65..];

    const Ed25519 = std.crypto.sign.Ed25519;
    const pk = try Ed25519.PublicKey.fromBytes(kp.public);
    const sig = Ed25519.Signature.fromBytes(sig_bytes[0..64].*);
    try sig.verify(message, pk);
}

test "solana_tx: compact-u16 encoding" {
    const allocator = std.testing.allocator;

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    try solana_tx.writeCompactU16(buf.writer(allocator), 0);
    try std.testing.expectEqualSlices(u8, &[_]u8{0}, buf.items);
    buf.clearRetainingCapacity();

    try solana_tx.writeCompactU16(buf.writer(allocator), 127);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x7F}, buf.items);
    buf.clearRetainingCapacity();

    try solana_tx.writeCompactU16(buf.writer(allocator), 128);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x80, 0x01}, buf.items);
    buf.clearRetainingCapacity();

    try solana_tx.writeCompactU16(buf.writer(allocator), 255);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xFF, 0x01}, buf.items);
    buf.clearRetainingCapacity();

    try solana_tx.writeCompactU16(buf.writer(allocator), 256);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x80, 0x02}, buf.items);
}
