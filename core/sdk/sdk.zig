//! SDK core: signed-request builder and response verifier.
//!
//! Stateless, WASM-safe. No network, no clock, no filesystem, no RNG.
//! Time and nonce are injected by the host (WASM cannot read a clock or
//! produce secure entropy without an import).
//!
//! Wire protocol (schema 1.1, see docs/api-contract-v1.md §1.5):
//!   - Method: POST
//!   - URL:    {gateway_base}/api/v1/actions/{action_path}
//!   - Headers:
//!       Content-Type:      application/json
//!       X-API-Version:     v1
//!       X-Xb77-Pubkey:     <hex 32B>
//!       X-Xb77-Timestamp:  <decimal unix milliseconds>
//!       X-Xb77-Nonce:      <hex 12B>
//!       X-Xb77-Signature:  <hex 64B Ed25519 over canonical bytes>
//!   - Body: payload_json (passed through verbatim)
//!
//! Canonical bytes signed:
//!   action_byte(1) || ts_be_u64_ms(8) || nonce(12) || payload_json
//!
//! Verifier checks the gateway response signature using the same canonical
//! form over the response body and an expected action byte.

const std = @import("std");

const Ed25519 = std.crypto.sign.Ed25519;

pub const Error = error{
    InvalidAction,
    InvalidPrivkey,
    InvalidSignature,
    InvalidResponse,
    OutOfMemory,
};

pub const Action = enum(u8) {
    submit_order = 0x01,
    register_agent = 0x02,
    claim_credits = 0x03,
    query_pulse = 0x04,
    link_agent = 0x05,

    pub fn path(self: Action) []const u8 {
        return switch (self) {
            .submit_order => "submit_order",
            .register_agent => "register_agent",
            .claim_credits => "claim_credits",
            .query_pulse => "query_pulse",
            .link_agent => "link_agent",
        };
    }

    pub fn fromU8(v: u8) Error!Action {
        return switch (v) {
            0x01 => .submit_order,
            0x02 => .register_agent,
            0x03 => .claim_credits,
            0x04 => .query_pulse,
            0x05 => .link_agent,
            else => Error.InvalidAction,
        };
    }
};

pub const SignedRequest = struct {
    url: []const u8,
    method: []const u8, // always "POST"
    headers_json: []const u8, // JSON object string
    body: []const u8, // pass-through of payload_json

    pub fn deinit(self: SignedRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        allocator.free(self.headers_json);
        allocator.free(self.body);
    }
};

/// Build a signed request ready for HTTP transport (wire schema 1.1).
///
/// `privkey` is the Ed25519 secret key in std.crypto canonical form
/// (64 bytes: seed[32] || pubkey[32]). The wrapper derives the pubkey
/// from the trailing 32 bytes — no separate pubkey argument needed.
///
/// `timestamp_unix_ms` MUST be unix milliseconds (server window: ±30000ms).
/// `nonce` is 12 random bytes; host is responsible for entropy.
pub fn buildSignedRequest(
    allocator: std.mem.Allocator,
    gateway_base: []const u8,
    action: Action,
    payload_json: []const u8,
    privkey: [64]u8,
    timestamp_unix_ms: u64,
    nonce: [12]u8,
) Error!SignedRequest {
    // Canonical bytes: action(1) || ts_be_ms(8) || nonce(12) || payload
    var canonical = allocator.alloc(u8, 1 + 8 + 12 + payload_json.len) catch return Error.OutOfMemory;
    defer allocator.free(canonical);
    canonical[0] = @intFromEnum(action);
    std.mem.writeInt(u64, canonical[1..9], timestamp_unix_ms, .big);
    @memcpy(canonical[9..21], &nonce);
    @memcpy(canonical[21..], payload_json);

    const sk = Ed25519.SecretKey.fromBytes(privkey) catch return Error.InvalidPrivkey;
    const pubkey_bytes: [32]u8 = privkey[32..64].*;
    const pk = Ed25519.PublicKey.fromBytes(pubkey_bytes) catch return Error.InvalidPrivkey;
    const kp = Ed25519.KeyPair{ .public_key = pk, .secret_key = sk };
    const signature = kp.sign(canonical, null) catch return Error.InvalidPrivkey;
    const sig_bytes = signature.toBytes();

    // URL: {base}/api/v1/actions/{action_path}
    const base_trimmed = std.mem.trimRight(u8, gateway_base, "/");
    const action_path = action.path();
    const url = std.fmt.allocPrint(
        allocator,
        "{s}/api/v1/actions/{s}",
        .{ base_trimmed, action_path },
    ) catch return Error.OutOfMemory;
    errdefer allocator.free(url);

    const pk_hex = std.fmt.bytesToHex(pubkey_bytes, .lower);
    const sig_hex = std.fmt.bytesToHex(sig_bytes, .lower);
    const nonce_hex = std.fmt.bytesToHex(nonce, .lower);

    const headers_json = std.fmt.allocPrint(
        allocator,
        "{{\"Content-Type\":\"application/json\",\"X-API-Version\":\"v1\",\"X-Xb77-Pubkey\":\"{s}\",\"X-Xb77-Timestamp\":\"{d}\",\"X-Xb77-Nonce\":\"{s}\",\"X-Xb77-Signature\":\"{s}\"}}",
        .{ pk_hex, timestamp_unix_ms, nonce_hex, sig_hex },
    ) catch return Error.OutOfMemory;
    errdefer allocator.free(headers_json);

    const body = allocator.dupe(u8, payload_json) catch return Error.OutOfMemory;

    return .{
        .url = url,
        .method = "POST",
        .headers_json = headers_json,
        .body = body,
    };
}

/// Verify a gateway response.
///
/// The gateway signs `expected_action || ts_be_u64_ms || response_body`
/// with its own Ed25519 key (no nonce — replay protection is owned by the
/// request side; responses don't need their own nonce). The caller supplies
/// the gateway's pubkey (typically pinned at install time as
/// XB77_GATEWAY_PUBKEY) and the ms-timestamp the gateway returned in its
/// `X-Xb77-Gateway-Timestamp` header.
pub fn verifyResponse(
    response_body: []const u8,
    expected_action: Action,
    response_timestamp_unix_ms: u64,
    gateway_pubkey: [32]u8,
    signature: [64]u8,
    allocator: std.mem.Allocator,
) Error!void {
    var canonical = allocator.alloc(u8, 1 + 8 + response_body.len) catch return Error.OutOfMemory;
    defer allocator.free(canonical);
    canonical[0] = @intFromEnum(expected_action);
    std.mem.writeInt(u64, canonical[1..9], response_timestamp_unix_ms, .big);
    @memcpy(canonical[9..], response_body);

    const pk = Ed25519.PublicKey.fromBytes(gateway_pubkey) catch return Error.InvalidSignature;
    const sig = Ed25519.Signature.fromBytes(signature);
    sig.verify(canonical, pk) catch return Error.InvalidSignature;
}

// -------------------- tests --------------------

test "Action enum roundtrip" {
    const all = [_]Action{ .submit_order, .register_agent, .claim_credits, .query_pulse };
    for (all) |a| {
        try std.testing.expectEqual(a, try Action.fromU8(@intFromEnum(a)));
    }
    try std.testing.expectError(Error.InvalidAction, Action.fromU8(0xFF));
}

test "buildSignedRequest produces well-formed components" {
    const allocator = std.testing.allocator;

    const kp = Ed25519.KeyPair.generate();
    const privkey = kp.secret_key.toBytes();
    const nonce: [12]u8 = .{ 0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x07, 0x18, 0x29, 0x3a, 0x4b, 0x5c };

    const req = try buildSignedRequest(
        allocator,
        "https://gateway.xb77.dev",
        .submit_order,
        "{\"symbol\":\"SOL/USDC\",\"amount\":1000}",
        privkey,
        1_700_000_000_000,
        nonce,
    );
    defer req.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "https://gateway.xb77.dev/api/v1/actions/submit_order", req.url);
    try std.testing.expectEqualSlices(u8, "POST", req.method);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "X-API-Version\":\"v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "X-Xb77-Pubkey") != null);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "X-Xb77-Nonce") != null);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "X-Xb77-Signature") != null);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "1700000000000") != null);
    try std.testing.expect(std.mem.indexOf(u8, req.headers_json, "a1b2c3d4e5f607182" ++ "93a4b5c") != null);
    try std.testing.expectEqualSlices(u8, "{\"symbol\":\"SOL/USDC\",\"amount\":1000}", req.body);
}

test "buildSignedRequest trims trailing slash from gateway base" {
    const allocator = std.testing.allocator;
    const kp = Ed25519.KeyPair.generate();
    const nonce: [12]u8 = std.mem.zeroes([12]u8);
    const req = try buildSignedRequest(
        allocator,
        "https://gateway.xb77.dev/",
        .query_pulse,
        "{}",
        kp.secret_key.toBytes(),
        42,
        nonce,
    );
    defer req.deinit(allocator);
    try std.testing.expectEqualSlices(u8, "https://gateway.xb77.dev/api/v1/actions/query_pulse", req.url);
}

test "signature roundtrip: gateway-side verification accepts our signed bytes" {
    const allocator = std.testing.allocator;
    const kp = Ed25519.KeyPair.generate();

    const payload = "{\"order\":\"buy 1 SOL\"}";
    const ts_ms: u64 = 1_700_000_123_456;
    const nonce: [12]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    const req = try buildSignedRequest(allocator, "https://g", .submit_order, payload, kp.secret_key.toBytes(), ts_ms, nonce);
    defer req.deinit(allocator);

    const sig_marker = "\"X-Xb77-Signature\":\"";
    const start = std.mem.indexOf(u8, req.headers_json, sig_marker).? + sig_marker.len;
    const sig_hex = req.headers_json[start .. start + 128];

    var sig_bytes: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&sig_bytes, sig_hex);

    // Reconstruct canonical: action(1) || ts_be_ms(8) || nonce(12) || payload.
    var canonical: [1 + 8 + 12 + payload.len]u8 = undefined;
    canonical[0] = @intFromEnum(Action.submit_order);
    std.mem.writeInt(u64, canonical[1..9], ts_ms, .big);
    @memcpy(canonical[9..21], &nonce);
    @memcpy(canonical[21..], payload);

    const sig = Ed25519.Signature.fromBytes(sig_bytes);
    try sig.verify(&canonical, kp.public_key);
}

test "verifyResponse accepts valid gateway signature" {
    const allocator = std.testing.allocator;
    const gateway_kp = Ed25519.KeyPair.generate();

    const response_body = "{\"status\":\"ok\",\"order_id\":\"abc123\"}";
    const ts: u64 = 1_700_001_000;

    // Simulate gateway-side signing
    var canonical: [1 + 8 + response_body.len]u8 = undefined;
    canonical[0] = @intFromEnum(Action.submit_order);
    std.mem.writeInt(u64, canonical[1..9], ts, .big);
    @memcpy(canonical[9..], response_body);

    const sig = try gateway_kp.sign(&canonical, null);

    try verifyResponse(
        response_body,
        .submit_order,
        ts,
        gateway_kp.public_key.toBytes(),
        sig.toBytes(),
        allocator,
    );
}

test "verifyResponse rejects tampered body" {
    const allocator = std.testing.allocator;
    const gateway_kp = Ed25519.KeyPair.generate();

    const response_body = "{\"status\":\"ok\"}";
    const ts: u64 = 1_700_001_000;

    var canonical: [1 + 8 + response_body.len]u8 = undefined;
    canonical[0] = @intFromEnum(Action.submit_order);
    std.mem.writeInt(u64, canonical[1..9], ts, .big);
    @memcpy(canonical[9..], response_body);
    const sig = try gateway_kp.sign(&canonical, null);

    const tampered = "{\"status\":\"hacked\"}";
    const result = verifyResponse(
        tampered,
        .submit_order,
        ts,
        gateway_kp.public_key.toBytes(),
        sig.toBytes(),
        allocator,
    );
    try std.testing.expectError(Error.InvalidSignature, result);
}
