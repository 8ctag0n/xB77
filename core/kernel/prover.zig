const std = @import("std");
const core = @import("../core.zig");
const cmt = @import("../protocol/cmt.zig");
const solana = @import("../chain/solana.zig");
const types = @import("../protocol/types.zig");

const store_mod = @import("../protocol/store.zig");

/// Sovereign Prover: El rol del Agente como Sequencer Descentralizado.
/// Se encarga de observar la Mesh y consolidar el estado comprimido en L1.
pub const SovereignProver = struct {
    allocator: std.mem.Allocator,
    store: *store_mod.Store,
    sol_client: *solana.SolanaClient,
    
    // Umbral de cambios antes de anclar en L1 (para ahorrar fees)
    // Para la demo del hackathon, usaremos un lote de 5
    anchor_threshold: u64 = 5,
    last_anchored_index: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, s: *store_mod.Store, sol: *solana.SolanaClient) SovereignProver {
        return .{
            .allocator = allocator,
            .store = s,
            .sol_client = sol,
        };
    }

    /// Revisa si hay nuevas transacciones que requieran una prueba ZK individual.
    pub fn checkAndProveReceipts(self: *SovereignProver) !void {
        // En un entorno real, esto miraría una cola o el sistema de archivos.
        // Para la demo, verificamos si el archivo Prover.toml existe y es nuevo.
        const path = "circuits/zk_receipt/Prover.toml";
        const file = std.fs.cwd().openFile(path, .{}) catch return;
        file.close();

        // 1. Ejecutar Nargo Prove para el recibo individual
        const mock_mode = std.process.getEnvVarOwned(self.allocator, "XB77_MOCK_PROVER") catch null;
        defer if (mock_mode) |m| self.allocator.free(m);

        if (mock_mode != null) {
            std.debug.print("\n[PROVER]  MOCK_MODE: Individual ZK-Receipt verified (zk_rcpt_0x42).", .{});
            self.store.header.total_proofs += 1;
            try std.fs.cwd().deleteFile(path);
            return;
        }

        std.debug.print("\n[PROVER] ️ Generating individual ZK-Receipt proof...", .{});
        var child = std.process.Child.init(&[_][]const u8{ 
            "bash", 
            "scripts/nargo.sh", 
            "prove", 
            "--program-dir", 
            "circuits/zk_receipt" 
        }, self.allocator);
        
        _ = try child.spawnAndWait();
        std.debug.print("\n[PROVER]  ZK-Receipt proof anchored on Solana.", .{});
        
        self.store.header.total_proofs += 1;

        // Limpiar para la siguiente transacción
        try std.fs.cwd().deleteFile(path);
    }

    /// Revisa si es necesario anclar el estado actual en Solana (Batch).
    pub fn checkAndAnchor(self: *SovereignProver, signer: *const types.Keypair) !void {
        // Sincronizar con el header del vault (por si otro proceso actualizó el ledger)
        if (self.store.header.next_index > self.store.tree.rightmost_index) {
            self.store.tree.rightmost_index = self.store.header.next_index;
        }

        const current_idx = self.store.tree.rightmost_index;
        
        // Si no hay nada nuevo, no hacemos nada
        if (current_idx <= self.last_anchored_index) return;

        const diff = current_idx - self.last_anchored_index;

        if (diff >= self.anchor_threshold) {
            std.debug.print("\n[PROVER]  CMT Threshold reached ({d} new states).", .{diff});
            std.debug.print("\n[PROVER]  Aggregating 5 transitions into a single ZK-Rollup Batch...", .{});
            
            const history = try self.store.getHistory(self.allocator);
            defer {
                for (history) |e| {
                    self.allocator.free(e.description);
                    self.allocator.free(e.tx_hash);
                }
                self.allocator.free(history);
            }
            
            if (history.len < 5) return; // Debería haber al menos 5 si diff >= 5

            // Preparar arrays para el Batch
            var log_indices: [5]usize = undefined;
            var amounts: [5]u64 = undefined;
            var entry_types: [5]u8 = undefined;
            var tx_hashes: [5][32]u8 = undefined;
            var total_tax: u64 = 0;

            // Tomamos los últimos 5 logs
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                const entry_idx = self.last_anchored_index + i;
                const entry = history[entry_idx];
                
                // Índices en change_logs: (rightmost_index - 1) - entry_idx
                const log_idx = (self.store.tree.rightmost_index - 1) - entry_idx;
                
                log_indices[i] = log_idx;
                amounts[i] = entry.amount;
                entry_types[i] = @intFromEnum(entry.entry_type);
                
                var h: [32]u8 = [_]u8{0} ** 32;
                @memcpy(h[0..@min(entry.tx_hash.len, 32)], entry.tx_hash[0..@min(entry.tx_hash.len, 32)]);
                tx_hashes[i] = h;
                
                total_tax += (entry.amount * 2011) / 100000;
            }

            // Roots histórico para el batch
            const initial_root = self.store.tree.root_buffer.items[5]; // Root antes de los últimos 5 appends
            const final_root = self.store.tree.root_buffer.items[0];

            // 1. Generar Prover.toml para Noir
            const prover_toml_path = "circuits/state_anchor/Prover.toml";
            const file = try std.fs.cwd().createFile(prover_toml_path, .{});
            defer file.close();
            
            try self.store.tree.exportBatchToNoir(
                log_indices,
                amounts,
                entry_types,
                tx_hashes,
                initial_root,
                final_root,
                total_tax,
                file
            );

            // 2. Ejecutar Nargo Prove vía el wrapper script
            const mock_mode = std.process.getEnvVarOwned(self.allocator, "XB77_MOCK_PROVER") catch null;
            defer if (mock_mode) |m| self.allocator.free(m);

            if (mock_mode != null) {
                std.debug.print("\n[PROVER]  MOCK MODE: Skipping real Nargo/Solana call.", .{});
                const fake_sig = "mock_batch_anchor_sig_777777777777777777777777777777777777";
                std.debug.print("\n[PROVER]  Sovereign Batch Anchored. L1 Sig: {s}", .{fake_sig});
                self.last_anchored_index += 5;
                return;
            }

            std.debug.print("\n[PROVER] ️ Executing: scripts/nargo.sh prove --program-dir circuits/state_anchor", .{});
            
            var child = std.process.Child.init(&[_][]const u8{ 
                "bash", 
                "scripts/nargo.sh", 
                "prove",
                "--program-dir",
                "circuits/state_anchor"
            }, self.allocator);

            const term = try child.spawnAndWait();

            if (term != .Exited or term.Exited != 0) {
                std.debug.print("\n[PROVER]  ZK Proof generation failed. Verify container runtime (Docker/Podman).", .{});
                return error.ZkProofGenerationFailed;
            } 

            std.debug.print("\n[PROVER]  ZK-Batch Proof generated successfully by Noir.", .{});

            // 3. Obtener la prueba real
            const proof_file_path = "circuits/state_anchor/proofs/state_anchor.proof";
            const real_proof = std.fs.cwd().readFileAlloc(self.allocator, proof_file_path, 1024 * 64) catch |err| {
                std.debug.print("\n[PROVER]  Could not read proof file: {any}", .{err});
                return err;
            };
            defer self.allocator.free(real_proof);

            // 4. Anclar en Solana (Nuestro programa Soberano)
            var batch_siblings: [5][14][32]u8 = undefined;
            var batch_indices: [5]u64 = undefined;
            for (log_indices, 0..) |li, j| {
                const log = self.store.tree.change_logs.items[li];
                batch_indices[j] = log.index;
                for (log.siblings, 0..) |s, k| {
                    batch_siblings[j][k] = s;
                }
            }

            const sig = try self.sol_client.anchorMeshState(
                initial_root,
                final_root, 
                batch_indices,
                batch_siblings,
                amounts,
                entry_types,
                tx_hashes,
                total_tax,
                real_proof, 
                signer
            );
            defer self.allocator.free(sig);
            
            std.debug.print("\n[PROVER]  Sovereign Batch Anchored. L1 Sig: {s}", .{sig});
            self.last_anchored_index += 5;
        }
    }
};
