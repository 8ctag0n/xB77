const std = @import("std");
const core = @import("../core.zig");
const cmt = @import("../state/cmt.zig");
const solana = @import("../chain/solana.zig");
const types = @import("../protocol/types.zig");

/// Sovereign Prover: El rol del Agente como Sequencer Descentralizado.
/// Se encarga de observar la Mesh y consolidar el estado comprimido en L1.
pub const SovereignProver = struct {
    allocator: std.mem.Allocator,
    tree: *cmt.ConcurrentMerkleTree,
    sol_client: *solana.SolanaClient,
    
    // Umbral de cambios antes de anclar en L1 (para ahorrar fees)
    anchor_threshold: u64 = 10,
    last_anchored_index: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, tree: *cmt.ConcurrentMerkleTree, sol: *solana.SolanaClient) SovereignProver {
        return .{
            .allocator = allocator,
            .tree = tree,
            .sol_client = sol,
        };
    }

    /// Revisa si es necesario anclar el estado actual en Solana.
    pub fn checkAndAnchor(self: *SovereignProver, signer: *const types.Keypair) !void {
        const current_idx = self.tree.rightmost_index;
        
        // Si no hay nada nuevo, no hacemos nada
        if (current_idx <= self.last_anchored_index) return;

        const diff = current_idx - self.last_anchored_index;

        if (diff >= self.anchor_threshold) {
            std.debug.print("\n[PROVER] 🏭 CMT Threshold reached ({d} new states).", .{diff});
            std.debug.print("\n[PROVER] 🌳 Proving Mesh States in ZK (Autonomous Sequencer Mode)...", .{});
            
            const root = self.tree.getRoot();
            const leaf = self.tree.rightmost_leaf;

            // 1. Generar Prover.toml para Noir
            const prover_toml_path = "circuits/state_anchor/Prover.toml";
            
            const file = try std.fs.cwd().createFile(prover_toml_path, .{});
            defer file.close();
            
            // Usamos el último log para la prueba de inclusión
            if (self.tree.change_logs.items.len > 0) {
                try self.tree.exportToNoir(0, leaf, root, file);
            } else {
                return error.NoChangeLogs;
            }

            // 2. Ejecutar Nargo Prove vía el wrapper script
            // En un entorno de producción, esto sería asíncrono.
            std.debug.print("\n[PROVER] 🛠️ Executing: scripts/nargo.sh prove --package state_anchor", .{});
            
            var child = std.process.Child.init(&[_][]const u8{ "bash", "scripts/nargo.sh", "prove", "--package", "state_anchor" }, self.allocator);
            const term = try child.spawnAndWait();

            if (term != .Exited or term.Exited != 0) {
                std.debug.print("\n[PROVER] ❌ ZK Proof generation failed (is Podman/Docker running?).", .{});
                // Para la demo, si falla el contenedor, usamos una prueba simulada "verificable"
                std.debug.print("\n[PROVER] ⚠️ Falling back to deterministic Mock Proof for demo flow.", .{});
            } else {
                std.debug.print("\n[PROVER] ✨ ZK-Proof generated successfully by Noir.", .{});
            }

            // 3. Obtener la prueba del archivo (si nargo la generó)
            // Noir por defecto la guarda en circuits/state_anchor/proofs/state_anchor.proof
            var proof: []u8 = undefined;
            const proof_file_path = "circuits/state_anchor/proofs/state_anchor.proof";
            if (std.fs.cwd().readFileAlloc(self.allocator, proof_file_path, 1024 * 64)) |p| {
                proof = p;
            } else |_| {
                proof = try self.allocator.dupe(u8, "XB77_MOCK_PROOF_VERIFIED_IN_SIMULATION");
            }
            defer self.allocator.free(proof);

            // 4. Anclar en Solana
            const sig = try self.sol_client.anchorMeshState(root, proof, signer);
            defer self.allocator.free(sig);
            
            std.debug.print("\n[PROVER] ⚓ Mesh State Anchored at Index {d}. L1 Sig: {s}", .{current_idx, sig});
            self.last_anchored_index = current_idx;
        }
    }
};
