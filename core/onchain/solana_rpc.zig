//! Minimal Solana JSON-RPC client.
//!
//! Mirrors solana-rpc.js (webapp_deploy/assets/src/lib/solana-rpc.js).
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
            std.debug.print("[SolanaRpc] RPC error: {}\n", .{e});
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
};
