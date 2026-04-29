const std = @import("std");
const solana = @import("../chain/solana.zig");

/// Toma data técnica y la convierte en "Contexto" humano para el LLM.
pub fn parseTransactionHistory(allocator: std.mem.Allocator, signatures: []const solana.SignatureInfo) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try list.appendSlice("Resumen de actividad reciente:\n");

    for (signatures) |sig| {
        const status = if (sig.err) "FALLIDA" else "EXITOSA";
        const line = try std.fmt.allocPrint(allocator, "- Transacción {s} en slot {d} [{s}]\n", .{ sig.signature, sig.slot, status });
        defer allocator.free(line);
        try list.appendSlice(line);
    }

    return list.toOwnedSlice();
}
