const std = @import("std");
const core = @import("core");
const solana = core.solana;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const endpoint = "http://127.0.0.1:8899";
    var client = solana.SolanaClient.init(allocator, endpoint);
    defer client.deinit();

    std.debug.print("\n[RPC CHECK] Connecting to Solana Local Validator at {s}...", .{endpoint});

    // Usamos una dirección de sistema para probar (System Program)
    const sys_program = "11111111111111111111111111111111";
    
    const balance = client.getBalance(sys_program) catch |err| {
        std.debug.print("\n[RPC CHECK] ❌ Failed to connect: {any}", .{err});
        std.debug.print("\n[HINT] Make sure 'solana-test-validator' is running.", .{});
        return;
    };

    std.debug.print("\n[RPC CHECK] ✅ Connected! System Program Balance: {d} lamports", .{balance});
}
