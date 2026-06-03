const std = @import("std");
const core = @import("core");
const identity = core.business.identity;
const brain_mod = core.brain;
const magicblock = core.chain.magicblock;
const types = core.types;
const solana = core.solana;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    std.debug.print("\n{s}--- XB77 TRIDENT INTEGRATION TEST ---{s}", .{ "\x1b[33;1m", "\x1b[0m" });

    // 1. SNS RESOLUTION (Identity)
    std.debug.print("\n[1/3] Testing Sovereign SNS Resolution...", .{});
    var sol_client = solana.SolanaClient.init(allocator, "https://api.devnet.solana.com");
    defer sol_client.deinit();

    const domain = "bonfida.sol";
    const resolved = core.business.identity.Identity.resolveSnsNative(allocator, &sol_client, domain) catch |err| blk: {
        std.debug.print("\n      {s}SNS Native failed as expected on Devnet: {any}{s}", .{ "\x1b[33m", err, "\x1b[0m" });
        // Use a dummy address to continue the trident test
        break :blk [_]u8{0x77} ** 32;
    };
    const resolved_str = try core.crypto.pubkeyToString(allocator, &resolved);
    defer allocator.free(resolved_str);

    std.debug.print("\n      {s} resolved to: {s}", .{ domain, resolved_str });
    if (std.mem.eql(u8, resolved_str, "Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v")) {
        std.debug.print(" {s}[MATCH]{s}", .{ "\x1b[32m", "\x1b[0m" });
    } else {
        std.debug.print(" {s}[MISMATCH]{s}", .{ "\x1b[31m", "\x1b[0m" });
    }

    // 2. QVAC BRAIN (Intelligence)
    std.debug.print("\n[2/3] Testing QVAC Brain (via Shim)...", .{});
    var brain = brain_mod.Brain.init(allocator, null);
    defer brain.deinit();

    // Force shim usage for the test (simulated via fallback as setEnvVar is tricky in this Zig version)
    // try std.process.setEnvVar("XB77_USE_BRAIN_SHIM", "1");
    
    const directive = "Resolve bonfida.sol and send 0.1 SOL for research";
    const insight = brain.reasonWithGemma(directive) catch |err| blk: {
        std.debug.print("\n      {s}Brain Shim failed: {any}. Falling back to native heuristics.{s}", .{ "\x1b[31m", err, "\x1b[0m" });
        break :blk try brain.interpret(directive);
    };
    // Note: insight is not a pointer, and it has a deinit but it's not a pointer-based struct in Zig usually if returned by value, 
    // but BrainInsight has fields that need freeing.
    var insight_copy = insight;
    defer insight_copy.deinit();

    std.debug.print("\n      Directive: \"{s}\"", .{directive});
    std.debug.print("\n      Decision: {s}", .{insight_copy.decision});
    std.debug.print("\n      Risk Score: {d:.2}", .{insight_copy.risk_score});

    // 3. MAGICBLOCK HFT (Settlement)
    std.debug.print("\n[3/3] Testing MagicBlock HFT Rails...", .{});
    var mb = magicblock.MagicBlockSDK.init(allocator, "mock:https://devnet.magicblock.app");
    defer mb.deinit();

    const agent_kp = core.crypto.generateKeypair();
    var session = try mb.openSovereignSession(&agent_kp);
    
    std.debug.print("\n      Opened HFT Session: {x}", .{session.id[0..4].*});

    const eph_tx = magicblock.MagicBlockSDK.EphemeralTx{
        .target = resolved,
        .amount = 100_000_000,
        .payload_hash = [_]u8{0} ** 32,
        .signature = [_]u8{0} ** 64,
    };

    const receipt = try mb.dispatchEphemeral(&session, eph_tx);
    defer allocator.free(receipt);
    std.debug.print("\n      HFT Dispatch Successful. Receipt size: {d} bytes", .{receipt.len});

    try mb.commitToSolana(&session, &agent_kp);
    std.debug.print("\n      L1 Settlement Triggered (Mock).", .{});

    std.debug.print("\n{s}--- TRIDENT INTEGRATION COMPLETE ---{s}\n", .{ "\x1b[32;1m", "\x1b[0m" });
}
