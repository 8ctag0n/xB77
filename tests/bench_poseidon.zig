const std = @import("std");
const poseidon = @import("../core/crypto/poseidon.zig");
const Poseidon = poseidon.Poseidon;

pub fn main() !void {
    var timer = try std.time.Timer.start();
    
    const iterations: usize = 100_000;
    
    std.debug.print("\n[BENCH ] Starting Deluxe Poseidon Benchmark ({d} iterations)...\n", .{iterations});
    
    timer.reset();
    var last_hash: u256 = 0;
    for (0..iterations) |i| {
        last_hash = Poseidon.hash2(i, last_hash);
    }
    
    const elapsed_ns = timer.read();
    const elapsed_ms = elapsed_ns / 1_000_000;
    const hashes_per_sec = (iterations * 1_000_000_000) / elapsed_ns;
    
    std.debug.print("[BENCH ] Completed in {d}ms\n", .{elapsed_ms});
    std.debug.print("[BENCH ] Throughput: {d} hashes/sec\n", .{hashes_per_sec});
    std.debug.print("[BENCH ] Last Hash: {x}...\n", .{last_hash >> 224});
    
    if (hashes_per_sec > 100_000) {
        std.debug.print("[BENCH ]  STATUS: EXTREME PERFORMANCE (DELUXE EDITION)\n\n", .{});
    } else {
        std.debug.print("[BENCH ]  STATUS: OPERATIONAL\n\n", .{});
    }
}
