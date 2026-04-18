const std = @import("std");
const types = @import("types.zig");

pub const Keccak256 = std.crypto.hash.sha3.Keccak256;

/// Genera una dirección de Ethereum a partir de una llave pública SECP256K1 (64 bytes).
pub fn addressFromPubkey(pubkey: [64]u8) types.EthAddress {
    var hash: [32]u8 = undefined;
    Keccak256.hash(&pubkey, &hash, .{});
    
    var addr: types.EthAddress = undefined;
    @memcpy(&addr, hash[12..32]);
    return addr;
}

/// Helper para imprimir direcciones EVM en Hex.
pub fn addressToHex(allocator: std.mem.Allocator, addr: types.EthAddress) ![]u8 {
    const hex_encoded = std.fmt.bytesToHex(addr, .lower);
    return try std.fmt.allocPrint(allocator, "0x{s}", .{hex_encoded});
}

/// Parsear dirección Hex a bytes.
pub fn hexToAddress(hex: []const u8) !types.EthAddress {
    const clean_hex = if (std.mem.startsWith(u8, hex, "0x")) hex[2..] else hex;
    if (clean_hex.len != 40) return error.InvalidAddressLength;
    
    var addr: types.EthAddress = undefined;
    _ = try std.fmt.hexToBytes(&addr, clean_hex);
    return addr;
}
