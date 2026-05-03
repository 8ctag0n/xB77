const std = @import("std");
const core = @import("core");
const solana = core.solana;
const identity = core.business.identity;
const crypto = core.crypto;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Usamos Mainnet para probar resolución real de SNS
    const endpoint = "https://api.mainnet-beta.solana.com";
    var client = solana.SolanaClient.init(allocator, endpoint);
    defer client.deinit();

    // 2. Probar Resolución vía API (Ground Truth)
    std.debug.print("\n[SNS TEST] Resolving 'bonfida.sol' via API...", .{});
    const owner_api = try identity.Identity.resolveSnsApi(allocator, &client, "bonfida.sol");
    const owner_api_str = try crypto.pubkeyToString(allocator, &owner_api);
    defer allocator.free(owner_api_str);
    std.debug.print("\n[SNS TEST] API Result: {s}", .{owner_api_str});

    // 3. Probar Resolución Nativa (Sovereign)
    std.debug.print("\n[SNS TEST] Resolving 'bonfida.sol' Natively...", .{});
    if (identity.Identity.resolveSnsNative(allocator, &client, "bonfida.sol")) |owner_native| {
        const owner_native_str = try crypto.pubkeyToString(allocator, &owner_native);
        defer allocator.free(owner_native_str);
        std.debug.print("\n[SNS TEST] Native Result: {s}", .{owner_native_str});
        if (std.mem.eql(u8, owner_native_str, owner_api_str)) {
            std.debug.print("\n[SNS TEST]  MATCH! Native engine is 100% Sovereign.", .{});
        } else {
            std.debug.print("\n[SNS TEST] ️ Mismatch between Native and API results.", .{});
        }
    } else |err| {
        std.debug.print("\n[SNS TEST]  Native resolution failed: {any}", .{err});
        std.debug.print("\n[SNS TEST] (This is expected until we fix the PDA derivation seeds).", .{});
    }
    std.debug.print("\n", .{});
}
