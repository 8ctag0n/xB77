//! WASM ABI surface for the xB77 SDK core.
//!
//! See docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.md
//! and the .addendum.md for the locked ABI conventions (A.2 error codes,
//! A.3 out-buffer protocol, A.4 UTF-8, A.9 wasm32-wasi).
//!
//! All exported functions follow these conventions:
//!   - Return value: u32 error code (0 = OK; see ErrorCode below).
//!   - Variable-length outputs use (out_ptr, out_max_len, out_actual_len_ptr).
//!   - Strings: UTF-8, no NUL terminator, explicit lengths.
//!
//! Host responsibilities:
//!   - Call wasm_alloc to obtain pointers for inputs/outputs.
//!   - Call wasm_free after consuming results.
//!   - Inject timestamps and entropy (WASM has no clock; getrandom comes via WASI).

const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const keystore = core.keystore;
const sdk = core.sdk_core;

// -------------------- error codes (addendum A.2) --------------------

pub const ErrorCode = enum(u32) {
    ok = 0,
    invalid_input = 1,
    buffer_too_small = 2,
    invalid_password = 3,
    invalid_signature = 4,
    invalid_action = 5,
    out_of_memory = 6,
    invalid_blob = 7,
};

inline fn code(c: ErrorCode) u32 {
    return @intFromEnum(c);
}

// -------------------- ABI version --------------------

const ABI_MAJOR: u16 = 1;
const ABI_MINOR: u16 = 1;

export fn xb77_abi_version() u32 {
    return (@as(u32, ABI_MAJOR) << 16) | @as(u32, ABI_MINOR);
}

// -------------------- memory --------------------

const wasm_allocator = std.heap.page_allocator;

/// Allocate `n_bytes` bytes. Returns the pointer as a u32 wasm offset, or 0 on OOM.
export fn wasm_alloc(n_bytes: u32) u32 {
    if (n_bytes == 0) return 0;
    const slice = wasm_allocator.alloc(u8, n_bytes) catch return 0;
    return @intCast(@intFromPtr(slice.ptr));
}

/// Free a previously allocated region. Caller must pass the original length.
export fn wasm_free(ptr: u32, n_bytes: u32) void {
    if (ptr == 0 or n_bytes == 0) return;
    const real_ptr: [*]u8 = @ptrFromInt(ptr);
    wasm_allocator.free(real_ptr[0..n_bytes]);
}

// -------------------- helpers --------------------

inline fn sliceFromPtr(ptr: u32, len: u32) []const u8 {
    if (len == 0) return &.{};
    const p: [*]const u8 = @ptrFromInt(ptr);
    return p[0..len];
}

inline fn writeActualLen(out_actual_len_ptr: u32, value: u32) void {
    if (out_actual_len_ptr == 0) return;
    const p: *u32 = @ptrFromInt(out_actual_len_ptr);
    p.* = value;
}

inline fn writeBytes(out_ptr: u32, bytes: []const u8) void {
    const dst: [*]u8 = @ptrFromInt(out_ptr);
    @memcpy(dst[0..bytes.len], bytes);
}

// -------------------- keystore --------------------

/// Seal a plaintext blob with a password.
/// out_actual_len always receives sealedSize(plain_len) on entry, regardless of error.
export fn keystore_seal(
    plain_ptr: u32,
    plain_len: u32,
    password_ptr: u32,
    password_len: u32,
    out_ptr: u32,
    out_max_len: u32,
    out_actual_len_ptr: u32,
) u32 {
    const required: u32 = @intCast(keystore.sealedSize(plain_len));
    writeActualLen(out_actual_len_ptr, required);
    if (out_max_len < required) return code(.buffer_too_small);

    const plain = sliceFromPtr(plain_ptr, plain_len);
    const password = sliceFromPtr(password_ptr, password_len);
    const out_slice: []u8 = blk: {
        const p: [*]u8 = @ptrFromInt(out_ptr);
        break :blk p[0..required];
    };

    keystore.seal(plain, password, out_slice) catch |err| return switch (err) {
        keystore.Error.OutputBufferTooSmall => code(.buffer_too_small),
        keystore.Error.BlobCorrupt => code(.invalid_input),
        else => code(.invalid_input),
    };
    return code(.ok);
}

/// Unseal a blob with a password.
export fn keystore_unseal(
    blob_ptr: u32,
    blob_len: u32,
    password_ptr: u32,
    password_len: u32,
    out_ptr: u32,
    out_max_len: u32,
    out_actual_len_ptr: u32,
) u32 {
    if (blob_len < keystore.SEAL_OVERHEAD) {
        writeActualLen(out_actual_len_ptr, 0);
        return code(.invalid_blob);
    }
    const required: u32 = blob_len - @as(u32, @intCast(keystore.SEAL_OVERHEAD));
    writeActualLen(out_actual_len_ptr, required);
    if (out_max_len < required) return code(.buffer_too_small);

    const blob = sliceFromPtr(blob_ptr, blob_len);
    const password = sliceFromPtr(password_ptr, password_len);
    const out_slice: []u8 = blk: {
        const p: [*]u8 = @ptrFromInt(out_ptr);
        break :blk p[0..required];
    };

    keystore.unseal(blob, password, out_slice) catch |err| return switch (err) {
        keystore.Error.InvalidPassword => code(.invalid_password),
        keystore.Error.BlobTooShort => code(.invalid_blob),
        keystore.Error.BlobCorrupt => code(.invalid_blob),
        else => code(.invalid_input),
    };
    return code(.ok);
}

/// Derive the Ed25519 public key from a 64-byte secret key (canonical form).
/// Writes exactly 32 bytes to out_pubkey_ptr. Fixed size: no actual_len needed.
export fn keystore_pubkey(privkey_ptr: u32, privkey_len: u32, out_pubkey_ptr: u32) u32 {
    if (privkey_len != 64) return code(.invalid_input);
    const priv = sliceFromPtr(privkey_ptr, privkey_len);
    // The canonical Ed25519 secret key in std.crypto is seed||pubkey;
    // the trailing 32 bytes are the public key already.
    writeBytes(out_pubkey_ptr, priv[32..64]);
    return code(.ok);
}

// -------------------- signed request --------------------

/// Build a signed gateway request.
///
/// The result has three variable-length parts (url, headers, body). To keep
/// the ABI manageable, each part gets its own out_ptr/out_max_len/out_actual_len_ptr
/// triple. If any of the three buffers is too small, the function writes all
/// three required lengths and returns BUFFER_TOO_SMALL — caller re-allocates
/// and retries with the now-known sizes.
export fn build_signed_request(
    action_byte: u32,
    payload_ptr: u32,
    payload_len: u32,
    privkey_ptr: u32,
    privkey_len: u32,
    timestamp_unix_ms: u64,
    nonce_ptr: u32,
    nonce_len: u32,
    gateway_base_ptr: u32,
    gateway_base_len: u32,
    out_url_ptr: u32,
    out_url_max: u32,
    out_url_len_ptr: u32,
    out_headers_ptr: u32,
    out_headers_max: u32,
    out_headers_len_ptr: u32,
    out_body_ptr: u32,
    out_body_max: u32,
    out_body_len_ptr: u32,
) u32 {
    if (privkey_len != 64) return code(.invalid_input);
    if (nonce_len != 12) return code(.invalid_input);
    if (action_byte > 0xFF) return code(.invalid_action);

    const action = sdk.Action.fromU8(@intCast(action_byte)) catch return code(.invalid_action);

    const privkey: [64]u8 = blk: {
        var buf: [64]u8 = undefined;
        const slice = sliceFromPtr(privkey_ptr, privkey_len);
        @memcpy(&buf, slice);
        break :blk buf;
    };

    const nonce: [12]u8 = blk: {
        var buf: [12]u8 = undefined;
        const slice = sliceFromPtr(nonce_ptr, nonce_len);
        @memcpy(&buf, slice);
        break :blk buf;
    };

    const req = sdk.buildSignedRequest(
        wasm_allocator,
        sliceFromPtr(gateway_base_ptr, gateway_base_len),
        action,
        sliceFromPtr(payload_ptr, payload_len),
        privkey,
        timestamp_unix_ms,
        nonce,
    ) catch |err| return switch (err) {
        sdk.Error.InvalidPrivkey => code(.invalid_input),
        sdk.Error.OutOfMemory => code(.out_of_memory),
        else => code(.invalid_input),
    };
    defer req.deinit(wasm_allocator);

    const url_req: u32 = @intCast(req.url.len);
    const hdr_req: u32 = @intCast(req.headers_json.len);
    const body_req: u32 = @intCast(req.body.len);
    writeActualLen(out_url_len_ptr, url_req);
    writeActualLen(out_headers_len_ptr, hdr_req);
    writeActualLen(out_body_len_ptr, body_req);

    if (out_url_max < url_req or out_headers_max < hdr_req or out_body_max < body_req) {
        return code(.buffer_too_small);
    }

    writeBytes(out_url_ptr, req.url);
    writeBytes(out_headers_ptr, req.headers_json);
    writeBytes(out_body_ptr, req.body);
    return code(.ok);
}

/// Verify a gateway response signature.
export fn verify_response(
    body_ptr: u32,
    body_len: u32,
    expected_action_byte: u32,
    response_timestamp_unix_ms: u64,
    gateway_pubkey_ptr: u32,
    gateway_pubkey_len: u32,
    signature_ptr: u32,
    signature_len: u32,
) u32 {
    if (gateway_pubkey_len != 32) return code(.invalid_input);
    if (signature_len != 64) return code(.invalid_input);
    if (expected_action_byte > 0xFF) return code(.invalid_action);

    const action = sdk.Action.fromU8(@intCast(expected_action_byte)) catch return code(.invalid_action);

    var pk: [32]u8 = undefined;
    @memcpy(&pk, sliceFromPtr(gateway_pubkey_ptr, gateway_pubkey_len));
    var sig: [64]u8 = undefined;
    @memcpy(&sig, sliceFromPtr(signature_ptr, signature_len));

    sdk.verifyResponse(
        sliceFromPtr(body_ptr, body_len),
        action,
        response_timestamp_unix_ms,
        pk,
        sig,
        wasm_allocator,
    ) catch |err| return switch (err) {
        sdk.Error.InvalidSignature => code(.invalid_signature),
        sdk.Error.OutOfMemory => code(.out_of_memory),
        else => code(.invalid_input),
    };
    return code(.ok);
}

// -------------------- native tests (compile-time validation of the module) --------------------

test "xb77_abi_version packs major and minor" {
    const v = xb77_abi_version();
    try std.testing.expectEqual(@as(u32, (@as(u32, ABI_MAJOR) << 16) | ABI_MINOR), v);
    try std.testing.expectEqual(@as(u32, (1 << 16) | 1), v);
}

test "ErrorCode contiguous from 0" {
    try std.testing.expectEqual(@as(u32, 0), code(.ok));
    try std.testing.expectEqual(@as(u32, 7), code(.invalid_blob));
}
