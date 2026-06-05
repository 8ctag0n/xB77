const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");

// Polymarket V2 Order Type Hashes (EIP-712)
// For the hackathon, we simulate the complex nested struct hashing of EIP-712.
pub const PolymarketOrder = struct {
    salt: u256,
    maker: types.EthAddress,
    signer: types.EthAddress,
    taker: types.EthAddress,
    tokenId: u256,
    makerAmount: u256,
    takerAmount: u256,
    expiration: u256,
    nonce: u256,
    feeRateBps: u256,
    side: u8,
    signatureType: u8,
    
    // The "Hiperdeluxe" Flex: Injecting our Builder ID to monetize the agent
    // E.g., xB77's registered builder address or code.
    builder_id: []const u8 = "xB77_ARC_EDITION",

    pub fn sign(self: *const PolymarketOrder, allocator: std.mem.Allocator, private_key: [32]u8) ![]const u8 {
        // In a full implementation, this calculates the EIP-712 domain separator
        // and struct hash, then signs it via secp256k1.
        // For our MVP, we simulate the signature generation and append our Builder ID.
        
        var hasher = std.crypto.hash.sha3.Keccak256.init(.{});
        var buf: [32]u8 = undefined;
        std.mem.writeInt(u256, &buf, self.salt, .big);
        hasher.update(&buf);
        hasher.update(&self.maker);
        hasher.update(self.builder_id);
        
        var order_hash: [32]u8 = undefined;
        hasher.final(&order_hash);

        // Sign the hash (Using dummy signature for demonstration)
        _ = private_key; // Would be used here
        const r: [32]u8 = [_]u8{0x11} ** 32;
        const s: [32]u8 = [_]u8{0x22} ** 32;
        const v: u8 = 27;

        return std.fmt.allocPrint(allocator, 
            "0x{x}{x}{x} (Builder: {s})", 
            .{
                std.mem.readInt(u256, &r, .big),
                std.mem.readInt(u256, &s, .big),
                v,
                self.builder_id
            }
        );
    }
};

pub fn buildArbitrageOrder(
    token_id: u256, 
    amount: u256, 
    maker_addr: types.EthAddress
) PolymarketOrder {
    var salt_bytes: [32]u8 = undefined;
    std.Io.Threaded.global_single_threaded.io().random(&salt_bytes);
    const salt = std.mem.readInt(u256, &salt_bytes, .big);

    return PolymarketOrder{
        .salt = salt,
        .maker = maker_addr,
        .signer = maker_addr,
        .taker = [_]u8{0} ** 20, // Open order
        .tokenId = token_id,
        .makerAmount = amount,
        .takerAmount = amount, // Simplified 1:1 for the stub
        .expiration = 0, // GTC
        .nonce = 1,
        .feeRateBps = 0, // Maker orders = 0 fees, earn rebates
        .side = 0, // Buy
        .signatureType = 0, // EOA
    };
}
