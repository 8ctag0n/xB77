const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const awp = @import("../protocol/awp.zig");

pub const SwapStatus = enum {
    initiated,
    pending_lock,
    locked,
    revealed,
    completed,
    expired,
    refunded,
};

pub const SovereignSwap = struct {
    id: [32]u8,
    status: SwapStatus,
    secret: [32]u8,
    hash: [32]u8,
    
    offered_asset: types.Asset,
    offered_amount: u64,
    wanted_asset: types.Asset,
    wanted_amount: u64,
    
    peer_id: [32]u8,
    timeout_blocks: u64,
    
    pub fn init(
        offered: types.Asset, 
        off_amt: u64, 
        wanted: types.Asset, 
        want_amt: u64, 
        peer: [32]u8,
    ) !SovereignSwap {
        var secret: [32]u8 = undefined;
        std.crypto.random.bytes(&secret);
        
        var hash: [32]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&secret);
        hasher.final(&hash);
        
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);

        return .{
            .id = id,
            .status = .initiated,
            .secret = secret,
            .hash = hash,
            .offered_asset = offered,
            .offered_amount = off_amt,
            .wanted_asset = wanted,
            .wanted_amount = want_amt,
            .peer_id = peer,
            .timeout_blocks = 100, // Placeholder
        };
    }
};

pub const SwapManager = struct {
    allocator: std.mem.Allocator,
    active_swaps: std.AutoHashMapUnmanaged([32]u8, SovereignSwap),

    pub fn init(allocator: std.mem.Allocator) SwapManager {
        return .{
            .allocator = allocator,
            .active_swaps = .{},
        };
    }

    pub fn deinit(self: *SwapManager) void {
        self.active_swaps.deinit(self.allocator);
    }

    pub fn createProposal(self: *SwapManager, offered: types.Asset, off_amt: u64, wanted: types.Asset, want_amt: u64, peer: [32]u8) !*SovereignSwap {
        const swap = try SovereignSwap.init(offered, off_amt, wanted, want_amt, peer);
        try self.active_swaps.put(self.allocator, swap.id, swap);
        return self.active_swaps.getPtr(swap.id).?;
    }

    /// Procesa un mensaje AWP de SwapRequest
    pub fn handleRequest(self: *SwapManager, msg: awp.SwapRequestMsg, peer_id: [32]u8) !void {
        std.debug.print("\n[SWAP  ] 🤝 Received Swap Request from ", .{});
        for (peer_id[0..4]) |b| std.debug.print("{x:0>2}", .{b});
        std.debug.print("\n         Offered: {d} {s} ({s})", .{ msg.offered_amount, msg.offered_asset.symbol, @tagName(msg.offered_asset.chain) });
        std.debug.print("\n         Wanted:  {d} {s} ({s})", .{ msg.wanted_amount, msg.wanted_asset.symbol, @tagName(msg.wanted_asset.chain) });
        
        const swap = SovereignSwap{
            .id = msg.lock_hash, 
            .status = .pending_lock,
            .secret = [_]u8{0} ** 32,
            .hash = msg.lock_hash,
            .offered_asset = .{ .chain = .solana, .symbol = "SOL" }, 
            .offered_amount = msg.wanted_amount, 
            .wanted_asset = .{ .chain = .base, .symbol = "USDC" },
            .wanted_amount = msg.offered_amount,
            .peer_id = peer_id,
            .timeout_blocks = msg.timeout,
        };
        try self.active_swaps.put(self.allocator, swap.id, swap);
    }

    /// Simula el bloqueo de fondos en cadena (HTLC)
    pub fn lock(self: *SwapManager, swap_id: [32]u8) !void {
        var swap = self.active_swaps.getPtr(swap_id) orelse return error.SwapNotFound;
        
        std.debug.print("\n[SWAP  ]  Locking {d} {s} on {s}...", .{
            swap.offered_amount,
            swap.offered_asset.symbol,
            @tagName(swap.offered_asset.chain)
        });

        // Simulación: aquí llamaríamos a ctx.sol_client.sendTransaction(...)
        // con un programa que implemente el HTLC.
        swap.status = .locked;
        
        std.debug.print("  Funds Locked with hash {x}...", .{swap.hash[0..4]});
    }

    /// Revela el secreto para completar el swap
    pub fn reveal(self: *SwapManager, swap_id: [32]u8) !void {
        var swap = self.active_swaps.getPtr(swap_id) orelse return error.SwapNotFound;
        if (swap.status != .locked) return error.SwapNotLocked;

        std.debug.print("\n[SWAP  ]  Revealing secret for swap {x}...", .{swap_id[0..4]});
        
        // Al revelar el secreto, el par puede reclamar los fondos en la otra cadena.
        swap.status = .revealed;
        
        std.debug.print("  Secret Revealed. Deal finalized.");
    }
};
