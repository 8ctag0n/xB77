const std = @import("std");
const core = @import("../core.zig");
const store = @import("../state/store.zig");
const types = @import("../protocol/types.zig");

pub const AnchorService = struct {
    allocator: std.mem.Allocator,
    store: *store.Store,
    last_anchored_index: u64 = 0,
    anchor_threshold: u64 = 5, // Anclamos cada 5 entradas en la demo

    pub fn init(allocator: std.mem.Allocator, s: *store.Store) AnchorService {
        return .{
            .allocator = allocator,
            .store = s,
        };
    }

    pub fn checkAndAnchor(self: *AnchorService) !void {
        const current_index = self.store.tree.rightmost_index;
        if (current_index >= self.last_anchored_index + self.anchor_threshold) {
            try self.anchor();
            self.last_anchored_index = current_index;
        }
    }

    fn anchor(self: *AnchorService) !void {
        std.debug.print("\n[ANCHOR] ⚓ CMT Threshold reached ({d} new entries). Generating Global Checkpoint...", .{self.anchor_threshold});
        
        const root = self.store.tree.getRoot();

        // 1. Exportar Prover.toml
        const tmp_dir = ".anchor_tmp";
        try std.fs.cwd().makePath(tmp_dir);
        defer std.fs.cwd().deleteTree(tmp_dir) catch {};

        const prover_path = try std.fs.path.join(self.allocator, &[_][]const u8{ tmp_dir, "Prover.toml" });
        defer self.allocator.free(prover_path);

        const file = try std.fs.cwd().createFile(prover_path, .{});
        defer file.close();

        // Necesitamos la hoja que corresponde al log
        // En este caso usamos la última registrada en el CMT
        const leaf = self.store.tree.rightmost_leaf;

        try self.store.tree.exportToNoir(0, leaf, root, file);

        // --- DEMO SIMULATION (NO PODMAN) ---
        // En un entorno real, aquí correríamos el Verificador Noir.
        // ------------------------------------

        std.debug.print("\n[ANCHOR] 🧠 ZK-Witness generated successfully (Simulated).", .{});

        // 3. Simular llamada On-Chain
        // En una implementación final, aquí usaríamos SolanaClient/EvmClient para llamar al Verificador.
        std.debug.print("\n[ANCHOR] 📡 Sending Global Checkpoint to Base (Sepolia) & Solana (Devnet)...", .{});
        std.debug.print("\n[ANCHOR] ✅ Global Anchor SUCCEEDED. New Sovereign Root: 0x", .{});
        for (root) |b| {
            std.debug.print("{x:0>2}", .{b});
        }
        std.debug.print("\n", .{});
    }
};
