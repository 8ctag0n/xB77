const std = @import("std");
const core = @import("core");
const ArbitrumAdapter = core.chain.arbitrum_adapter.ArbitrumAdapter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    std.debug.print("\n--- xB77 Local Arbitrum Adapter Test ---\n", .{});

    var adapter = ArbitrumAdapter.init(
        allocator,
        "http://localhost:8547",
        [_]u8{0x42} ** 20,
        [_]u8{0x77} ** 20
    );
    defer adapter.deinit();

    const provider = adapter.provider();

    // Test 1: Action that should pass
    std.debug.print("\nTest 1: Safe Transfer\n", .{});
    const tx1 = provider.sendTx(.{ .transfer = .{ .to = "0xrecipient", .amount = 100 } }) catch |err| {
        std.debug.print("Unexpected Error: {}\n", .{err});
        return;
    };
    std.debug.print("TX Hash: {s}\n", .{tx1});

    // Test 2: Action that should be blocked locally
    std.debug.print("\nTest 2: Toxic Transfer (Blocking)\n", .{});
    const tx2 = provider.sendTx(.{ .transfer = .{ .to = "0xtoxic_recipient", .amount = 666 } }) catch |err| {
        if (err == error.ConstitutionalViolation) {
            std.debug.print("SUCCESS: Transaction correctly blocked by Sovereign Shield.\n", .{});
            return;
        }
        return err;
    };
    std.debug.print("FAILURE: Toxic transaction was NOT blocked. TX: {s}\n", .{tx2});
}
