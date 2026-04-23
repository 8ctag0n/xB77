const std = @import("std");
const core = @import("core");
const store = core.store;
const types = core.types;

test "Store - Basic record and retrieve" {
    const allocator = std.testing.allocator;
    const test_path = "./.test_xb77";
    defer std.fs.cwd().deleteTree(test_path) catch {};

    var s = try store.Store.init(allocator, test_path);
    defer s.deinit();

    const entry = store.LedgerEntry{
        .timestamp = 123456789,
        .chain = .solana,
        .entry_type = .audit,
        .description = "Test audit entry",
        .amount = 1000,
        .tx_hash = "fake_hash",
    };

    try s.record(entry);

    const entries = try s.getEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.description);
            allocator.free(e.tx_hash);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqual(entry.timestamp, entries[0].timestamp);
    try std.testing.expectEqualStrings(entry.description, entries[0].description);
    try std.testing.expectEqualStrings(entry.tx_hash, entries[0].tx_hash);
}
