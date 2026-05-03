const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const cmt = @import("../state/cmt.zig");

/// Estructura de una cuenta comprimida (Ficha de la Bóveda)
/// Usamos extern struct para asegurar un layout de memoria determinista
/// compatible con mmap y operaciones zero-copy.
pub const CompressedAccount = extern struct {
    owner: types.Pubkey,
    amount: u64,
    nonce: u64,
    asset_id: [32]u8, // Hash del tipo de activo

    // --- Task 4: Extended Schema (Singularity Ready) ---
    reputation: u32 = 0,
    flags: u32 = 0,           // Bits: [0: admin, 1: blocked, 2: whitelisted, ...]
    ai_metadata_hash: [32]u8 = [_]u8{0} ** 32, // Hash de la "conciencia" del agente

    pub fn hash(self: *const CompressedAccount, out: *[32]u8) void {
        const ptr: [*]const u8 = @ptrCast(self);
        // Hashing del struct completo (120 bytes) usando el motor C optimizado (Fixed in Round 2)
        cmt_keccak256(ptr, @sizeOf(CompressedAccount), out.ptr);
    }
};

pub extern fn cmt_keccak256(data: [*]const u8, len: usize, out: [*]u8) void;

/// Motor de Compresión Prioritario xB77
pub const CompressionEngine = struct {
    allocator: std.mem.Allocator,
    sovereign_tax: u64 = 111, // El impuesto sagrado

    pub fn init(allocator: std.mem.Allocator) CompressionEngine {
        return .{ .allocator = allocator };
    }

    /// Calcula el nuevo estado tras una transferencia interna comprimida.
    /// Opera directamente sobre punteros (Zero-Copy) que pueden estar en mmap.
    pub fn transfer(
        self: *CompressionEngine,
        from_acc: *CompressedAccount,
        to_acc: *CompressedAccount,
        amount: u64,
    ) !void {
        const total_deduction = amount + self.sovereign_tax;
        
        if (from_acc.amount < total_deduction) {
            return error.InsufficientCompressedFunds;
        }

        // Modificación in-place (Directo al mmap si los punteros vienen de ahí)
        from_acc.amount -= total_deduction;
        to_acc.amount += amount;
        from_acc.nonce += 1;
        
        std.debug.print("\n[COMP ] ️ Sovereign Tax of {d} lamports collected.", .{self.sovereign_tax});
        std.debug.print("\n[COMP ]  State Updated: {d} transferred privately.", .{amount});
        }

        /// Genera los artefactos necesarios para que Noir verifique la transición de estado.
        pub fn generateTransitionProof(
        self: *CompressionEngine,
        tree: *const cmt.ConcurrentMerkleTree,
        from_idx: u64,
        to_idx: u64,
        amount: u64,
        target_dir: []const u8,
        ) !void {
        _ = self;

        // 1. Obtener pruebas de inclusión actuales
        const from_siblings = try tree.allocator.alloc([32]u8, 14);
        defer tree.allocator.free(from_siblings);
        try tree.getProof(from_idx, from_siblings);

        const to_siblings = try tree.allocator.alloc([32]u8, 14);
        defer tree.allocator.free(to_siblings);
        try tree.getProof(to_idx, to_siblings);
        // 2. Crear el directorio si no existe
        std.fs.cwd().makePath(target_dir) catch {};
        const prover_path = try std.fs.path.join(tree.allocator, &[_][]const u8{ target_dir, "Prover.toml" });
        defer tree.allocator.free(prover_path);

        const file = try std.fs.cwd().createFile(prover_path, .{});
        defer file.close();
        var buf: [4096]u8 = undefined;
        var w_buffered = file.writer(&buf);

        try w_buffered.interface.print("root = {s}\n", .{try formatArray(tree.allocator, tree.getRoot())});
        try w_buffered.interface.print("amount = {d}\n", .{amount});
        try w_buffered.interface.print("tax = 111\n", .{});

        try w_buffered.interface.print("from_index = {d}\n", .{from_idx});
        try w_buffered.interface.print("from_siblings = [\n", .{});
        for (from_siblings, 0..) |s, i| {
            try w_buffered.interface.print("  {s}{s}\n", .{ try formatArray(tree.allocator, s), if (i == 13) "" else "," });
        }
        try w_buffered.interface.print("]\n", .{});

        try w_buffered.end();

        // Nota: Aquí deberíamos pasar los datos crudos de las cuentas para el hash
        // Por simplicidad en la demo, usamos placeholders
        try w_buffered.interface.print("from_account_data_old = [{d}, 0, 0, ...]\n", .{from_idx}); // Mock
        try w_buffered.interface.print("from_amount_old = 1000000\n", .{}); // Mock

        // ... Repetir para 'to' ...
        try w_buffered.end();

        std.debug.print("\n[ZK    ] ️ ZK-Transition artifacts generated at {s}", .{target_dir});
        }

        fn formatArray(allocator: std.mem.Allocator, arr: [32]u8) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        try list.append('[');
        for (arr, 0..) |b, i| {
            const s = try std.fmt.allocPrint(allocator, "{d}{s}", .{ b, if (i == 31) "" else ", " });
            defer allocator.free(s);
            try list.appendSlice(s);
        }
        try list.append(']');
        return list.toOwnedSlice();
        }

};

test "Zero-Copy: Direct memory manipulation" {
    var raw_data: [160]u8 = [_]u8{0} ** 160;
    
    // Simulamos que estos punteros apuntan al mmap
    var acc1: *CompressedAccount = @ptrCast(@alignCast(raw_data[0..80]));
    var acc2: *CompressedAccount = @ptrCast(@alignCast(raw_data[80..160]));
    
    acc1.owner = [_]u8{0x11} ** 32;
    acc1.amount = 1000;
    acc1.asset_id = [_]u8{0xAA} ** 32;
    
    acc2.owner = [_]u8{0x22} ** 32;
    acc2.amount = 0;
    acc2.asset_id = [_]u8{0xAA} ** 32;

    var engine = CompressionEngine.init(std.testing.allocator);
    try engine.transfer(acc1, acc2, 500);

    // Verificamos que el buffer "crudo" cambió
    try std.testing.expectEqual(acc1.amount, 1000 - 500 - 111);
    try std.testing.expectEqual(acc2.amount, 500);
    try std.testing.expectEqual(acc1.nonce, 1);
    
    // El hash debe ser consistente
    var h1: [32]u8 = undefined;
    acc1.hash(&h1);
    var h2: [32]u8 = undefined;
    acc2.hash(&h2);
    
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}
