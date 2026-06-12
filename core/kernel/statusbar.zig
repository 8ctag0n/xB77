const std = @import("std");

pub var settle_count = std.atomic.Value(u32).init(0);
pub var anchor_count = std.atomic.Value(u32).init(0);
pub var zk_count = std.atomic.Value(u32).init(0);
pub var start_ms: i64 = 0;
pub var mock_mode: bool = false;

var rpc_buf: [32]u8 = undefined;
var rpc_len: usize = 0;

var last_tx_buf: [12]u8 = [_]u8{'-'} ** 12;
var last_tx_lock = std.atomic.Value(bool).init(false);

pub fn init(mock: bool, rpc: []const u8) void {
    mock_mode = mock;
    start_ms = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds();
    const n = @min(rpc.len, rpc_buf.len);
    @memcpy(rpc_buf[0..n], rpc[0..n]);
    rpc_len = n;
}

pub fn onSettle(tx: []const u8) void {
    _ = settle_count.fetchAdd(1, .monotonic);
    setTx(tx);
}

pub fn onAnchor(tx: []const u8) void {
    _ = anchor_count.fetchAdd(1, .monotonic);
    setTx(tx);
}

pub fn onZkVerify() void {
    _ = zk_count.fetchAdd(1, .monotonic);
}

fn setTx(tx: []const u8) void {
    while (last_tx_lock.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {}
    defer last_tx_lock.store(false, .release);
    const n = @min(tx.len, 12);
    @memcpy(last_tx_buf[0..n], tx[0..n]);
    if (n < 12) @memset(last_tx_buf[n..12], ' ');
}

pub fn render() void {
    const now_ms = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds();
    const elapsed_s: u64 = @intCast(@divTrunc(now_ms - start_ms, 1000));
    const mins = elapsed_s / 60;
    const secs = elapsed_s % 60;

    const s = settle_count.load(.monotonic);
    const a = anchor_count.load(.monotonic);
    const z = zk_count.load(.monotonic);

    while (last_tx_lock.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {}
    const tx = last_tx_buf;
    last_tx_lock.store(false, .release);

    const mode: []const u8 = if (mock_mode) "\x1b[33mMOCK\x1b[0m" else "\x1b[32mLIVE\x1b[0m";
    const rpc = rpc_buf[0..rpc_len];

    std.debug.print(
        "\n\x1b[1m[xB77]\x1b[0m  up {d}m{d:02}s" ++
        "  \x1b[2m│\x1b[0m  settle \x1b[32m×{d}\x1b[0m" ++
        "  anchor \x1b[34m×{d}\x1b[0m" ++
        "  zk \x1b[35m×{d}\x1b[0m" ++
        "  \x1b[2m│\x1b[0m  last \x1b[33m{s}\x1b[0m" ++
        "  \x1b[2m│\x1b[0m  {s}  \x1b[2m{s}\x1b[0m",
        .{ mins, secs, s, a, z, tx, mode, rpc },
    );
}
