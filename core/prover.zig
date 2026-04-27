const std = @import("std");
const core = @import("core.zig");
const cmt = @import("cmt.zig");
const solana = @import("solana.zig");
const types = @import("types.zig");

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
        const diff = current_idx - self.last_anchored_index;

        if (diff >= self.anchor_threshold) {
            std.debug.print("\n[PROVER] 🏭 Batch Threshold Reached ({d} new states). Generating Mesh Proof...", .{diff});
            
            // Aquí llamaríamos a Noir para generar una prueba recursiva del lote (Batch)
            // Por ahora usamos una prueba simulada.
            const mock_proof = "ZK_BATCH_PROOF_FOR_XB77_MESH";
            
            const root = self.tree.getRoot();
            const sig = try self.sol_client.anchorMeshState(root, mock_proof, signer);
            defer self.allocator.free(sig);
            
            std.debug.print("\n[PROVER] ⚓ Mesh State Anchored at Index {d}. L1 Sig: {s}", .{current_idx, sig});
            self.last_anchored_index = current_idx;
        }
    }
};
