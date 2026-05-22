//! Minimal Solana JSON-RPC client.
//!
//! Mirrors solana-rpc.js (apps/web/assets/src/lib/solana-rpc.js).
//!
//! Provides:
//!   - getLatestBlockhash() → [32]u8
//!   - sendRawTransaction(bytes) → []u8 (base58 signature, owned)
//!   - getSignatureStatuses(sigs) → status info
//!   - requestAirdrop(pubkey_b58, lamports)
//!   - getBalance(pubkey_b58) → u64

const std = @import("std");
const http = @import("../mesh/http.zig");
const crypto_mod = @import("../security/crypto.zig");

pub const SolanaRpc = struct {
    allocator: std.mem.Allocator,
    url: []const u8,
    http_client: http.HttpClient,
    request_id: u32,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) SolanaRpc {
        return .{
            .allocator = allocator,
            .url = url,
            .http_client = http.HttpClient.init(allocator),
            .request_id = 0,
        };
    }

    pub fn deinit(self: *SolanaRpc) void {
        _ = self;
    }

    fn nextId(self: *SolanaRpc) u32 {
        self.request_id += 1;
        return self.request_id;
    }

    fn call(self: *SolanaRpc, body: []const u8) !std.json.Parsed(std.json.Value) {
        var resp = try self.http_client.post(self.url, body);
        defer resp.deinit();

        if (resp.status != 200) {
            std.debug.print("[SolanaRpc] HTTP {d}: {s}\n", .{ resp.status, resp.body });
            return error.HttpError;
        }

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            resp.body,
            .{ .ignore_unknown_fields = true },
        );

        if (parsed.value.object.get("error")) |e| {
            std.debug.print("[SolanaRpc] RPC error: {f}\n", .{std.json.fmt(e, .{})});
            parsed.deinit();
            return error.RpcError;
        }

        return parsed;
    }

    /// Returns the recent blockhash as a 32-byte array (decoded from base58).
    pub fn getLatestBlockhash(self: *SolanaRpc) ![32]u8 {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"getLatestBlockhash","params":[{{"commitment":"confirmed"}}]}}
        ,
            .{self.nextId()},
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        const bh_str = value.object.get("blockhash") orelse return error.InvalidResponse;

        return crypto_mod.stringToPubkey(self.allocator, bh_str.string);
    }

    /// Send pre-signed raw bytes. Returns owned base58 signature string.
    pub fn sendRawTransaction(self: *SolanaRpc, raw_bytes: []const u8) ![]u8 {
        // Encode as base64.
        const encoder = std.base64.standard.Encoder;
        const b64_len = encoder.calcSize(raw_bytes.len);
        const b64 = try self.allocator.alloc(u8, b64_len);
        defer self.allocator.free(b64);
        _ = encoder.encode(b64, raw_bytes);

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"sendTransaction","params":["{s}",{{"encoding":"base64","skipPreflight":false,"preflightCommitment":"confirmed"}}]}}
        ,
            .{ self.nextId(), b64 },
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse {
            std.debug.print("[SolanaRpc] sendTransaction: no result field\n", .{});
            return error.InvalidResponse;
        };

        return self.allocator.dupe(u8, result.string);
    }

    pub const SignatureStatus = struct {
        confirmation_status: ?[]const u8,
        err: bool,
        slot: u64,
    };

    /// Returns null for unknown signatures.
    pub fn getSignatureStatus(self: *SolanaRpc, sig: []const u8) !?SignatureStatus {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"getSignatureStatuses","params":[["{s}"],{{"searchTransactionHistory":false}}]}}
        ,
            .{ self.nextId(), sig },
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;

        if (value.array.items.len == 0) return null;
        const entry = value.array.items[0];
        if (entry == .null) return null;

        const slot: u64 = if (entry.object.get("slot")) |s| @intCast(s.integer) else 0;
        const err = (entry.object.get("err") orelse .null) != .null;
        const status: ?[]const u8 = if (entry.object.get("confirmationStatus")) |cs|
            cs.string
        else
            null;

        return SignatureStatus{
            .confirmation_status = status,
            .err = err,
            .slot = slot,
        };
    }

    /// Poll until confirmed or timeout. Returns true if confirmed.
    pub fn confirmSignature(
        self: *SolanaRpc,
        sig: []const u8,
        timeout_ms: u64,
        interval_ms: u64,
    ) !bool {
        const t0: u64 = @intCast(std.time.milliTimestamp());
        while (true) {
            const elapsed: u64 = @intCast(std.time.milliTimestamp() - @as(i64, @intCast(t0)));
            if (elapsed >= timeout_ms) return false;

            if (try self.getSignatureStatus(sig)) |s| {
                if (s.err) return error.TransactionFailed;
                if (s.confirmation_status) |cs| {
                    if (std.mem.eql(u8, cs, "confirmed") or std.mem.eql(u8, cs, "finalized")) {
                        return true;
                    }
                }
            }

            std.Thread.sleep(interval_ms * std.time.ns_per_ms);
        }
    }

    pub fn requestAirdrop(self: *SolanaRpc, pubkey_b58: []const u8, lamports: u64) !void {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"requestAirdrop","params":["{s}",{d}]}}
        ,
            .{ self.nextId(), pubkey_b58, lamports },
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();
        // result is the airdrop signature; ignore it.
    }

    pub fn getBalance(self: *SolanaRpc, pubkey_b58: []const u8) !u64 {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"getBalance","params":["{s}",{{"commitment":"confirmed"}}]}}
        ,
            .{ self.nextId(), pubkey_b58 },
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        return @intCast(value.integer);
    }

    /// One entry from `getSignaturesForAddress`.
    pub const SignatureEntry = struct {
        signature: []u8, // owned
        slot: u64,
        block_time: ?i64,
        err_present: bool,

        pub fn deinit(self: *SignatureEntry, alloc: std.mem.Allocator) void {
            alloc.free(self.signature);
        }
    };

    /// Calls `getSignaturesForAddress`. Returns up to `limit` newest signatures
    /// for `address_b58`. If `until_sig` is non-null, stops at that boundary.
    /// Caller owns the returned slice and each entry; use `freeSignatures`.
    pub fn getSignaturesForAddress(
        self: *SolanaRpc,
        address_b58: []const u8,
        limit: u32,
        until_sig: ?[]const u8,
    ) ![]SignatureEntry {
        var body_buf = std.ArrayListUnmanaged(u8){};
        defer body_buf.deinit(self.allocator);
        const w = body_buf.writer(self.allocator);
        try w.print(
            \\{{"jsonrpc":"2.0","id":{d},"method":"getSignaturesForAddress","params":["{s}",{{"limit":{d},"commitment":"confirmed"
        ,
            .{ self.nextId(), address_b58, limit });
        if (until_sig) |u| try w.print("," ++ "\"until\":\"{s}\"", .{u});
        try w.writeAll("}]}");

        const parsed = try self.call(body_buf.items);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const arr = result.array;
        var out = try self.allocator.alloc(SignatureEntry, arr.items.len);
        var i: usize = 0;
        errdefer {
            var j: usize = 0;
            while (j < i) : (j += 1) out[j].deinit(self.allocator);
            self.allocator.free(out);
        }
        while (i < arr.items.len) : (i += 1) {
            const obj = arr.items[i].object;
            const sig = obj.get("signature") orelse return error.InvalidResponse;
            const slot = obj.get("slot") orelse return error.InvalidResponse;
            const bt = obj.get("blockTime");
            const err = obj.get("err");
            out[i] = .{
                .signature = try self.allocator.dupe(u8, sig.string),
                .slot = @intCast(slot.integer),
                .block_time = if (bt) |v| (if (v == .null) null else @as(i64, @intCast(v.integer))) else null,
                .err_present = if (err) |v| (v != .null) else false,
            };
        }
        return out;
    }

    pub fn freeSignatures(self: *SolanaRpc, entries: []SignatureEntry) void {
        for (entries) |*e| e.deinit(self.allocator);
        self.allocator.free(entries);
    }

    /// Returns the account's owner pubkey (base58) if the account exists,
    /// or null if it does not exist on chain. Caller owns the returned slice.
    pub fn getAccountOwner(self: *SolanaRpc, pubkey_b58: []const u8) !?[]u8 {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":{d},"method":"getAccountInfo","params":["{s}",{{"commitment":"confirmed","encoding":"base64"}}]}}
        ,
            .{ self.nextId(), pubkey_b58 },
        );
        defer self.allocator.free(body);

        const parsed = try self.call(body);
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return null;
        if (value == .null) return null;
        const owner = value.object.get("owner") orelse return error.InvalidResponse;
        return try self.allocator.dupe(u8, owner.string);
    }
};
