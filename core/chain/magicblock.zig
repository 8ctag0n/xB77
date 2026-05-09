const std = @import("std");
const core = @import("../core.zig");
const types = core.types;
const crypto = core.crypto;
const solana_mod = @import("../chain/solana.zig");

/// MagicBlock Sovereign SDK (Native Zig Implementation).
/// Focuses on Private Ephemeral Rollups (PER) for HFT Agent Commerce.
pub const MagicBlockSDK = struct {
    allocator: std.mem.Allocator,
    sequencer_url: []const u8,
    sol_client: ?*solana_mod.SolanaClient = null,
    
    pub const Session = struct {
        id: [32]u8,
        authority: types.Pubkey,
        expiry: i64,
        is_active: bool,

        pub fn isExpired(self: *const Session) bool {
            return std.time.timestamp() >= self.expiry;
        }
    };

    pub const EphemeralTx = struct {
        target: types.Pubkey,
        amount: u64,
        payload_hash: [32]u8,
        signature: [64]u8,
    };

    pub fn init(allocator: std.mem.Allocator, url: []const u8) MagicBlockSDK {
        return .{
            .allocator = allocator,
            .sequencer_url = allocator.dupe(u8, url) catch "https://devnet.magicblock.app",
        };
    }

    pub fn deinit(self: *MagicBlockSDK) void {
        self.allocator.free(self.sequencer_url);
    }

    /// Abre una sesión PER nativamente.
    /// Involucra una transacción on-chain inicial en Solana para bloquear el estado.
    pub fn openSovereignSession(self: *MagicBlockSDK, agent_kp: *const types.Keypair) !Session {
        std.debug.print("\n[MAGIC ] ️ Initiating Sovereign Session (PER) for Agent {x}...", .{agent_kp.public[0..4]});
        
        // 1. Generar Session ID aleatorio
        var session_id: [32]u8 = undefined;
        std.crypto.random.bytes(&session_id);

        const expiry = std.time.timestamp() + 3600; // 1 hora de turbo

        // 2. Anclar el Escrow en Solana (L1) REAL
        if (self.sol_client) |sol| {
            const tx_mod = @import("../protocol/tx.zig");
            const amount: u64 = 2_000_000_000; // 2.0 SOL hardcoded for the demo session

            std.debug.print("\n[MAGIC ]  Locking {d} lamports in L1 Escrow for Session {x}...", .{amount, session_id[0..4].*});
            
            const ix_data = try tx_mod.buildOpenPerSessionInstruction(self.allocator, amount, session_id, expiry);
            defer self.allocator.free(ix_data);

            const program_id = try crypto.stringToPubkey(self.allocator, "FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv");
            
            // PDA del Escrow: [b"per_escrow", agent_pubkey, session_id]
            var seeds = [_][]const u8{ "per_escrow", &agent_kp.public, &session_id };
            const pda_res = try crypto.findProgramAddress(&seeds, &program_id);
            
            // Build and sign TX
            const blockhash = try sol.getLatestBlockhash();
            
            var buf = std.ArrayListUnmanaged(u8){};
            defer buf.deinit(self.allocator);
            const writer = buf.writer(self.allocator);

            try tx_mod.writeCompactU16(writer, 1);
            try buf.appendNTimes(self.allocator, 0, 64);
            
            const message_start = buf.items.len;
            try writer.writeByte(1); // num_sigs
            try writer.writeByte(0); // num_signed_readonly
            try writer.writeByte(2); // num_unsigned_readonly (program, system)
            
            try tx_mod.writeCompactU16(writer, 4); // signer, pda, program, system
            try buf.appendSlice(self.allocator, &agent_kp.public);
            try buf.appendSlice(self.allocator, &pda_res.address);
            try buf.appendSlice(self.allocator, &program_id);
            const system_program = [_]u8{0} ** 32;
            try buf.appendSlice(self.allocator, &system_program);
            
            try buf.appendSlice(self.allocator, &blockhash);
            
            try tx_mod.writeCompactU16(writer, 1);
            try writer.writeByte(2); // program_id index
            try tx_mod.writeCompactU16(writer, 3); // 3 accounts
            try writer.writeByte(0); // signer
            try writer.writeByte(1); // escrow pda
            try writer.writeByte(3); // system program
            
            try tx_mod.writeCompactU16(writer, @intCast(ix_data.len));
            try buf.appendSlice(self.allocator, ix_data);

            const message = buf.items[message_start..];
            const signature = crypto.sign(message, agent_kp);
            @memcpy(buf.items[1..65], &signature);

            const sig = try sol.sendTransaction(buf.items);
            std.debug.print("\n[MAGIC ]  L1 Escrow Anchor Successful. Sig: {s}", .{sig});
            self.allocator.free(sig);
        }

        const session = Session{
            .id = session_id,
            .authority = agent_kp.public,
            .expiry = expiry,
            .is_active = true,
        };

        std.debug.print("\n[MAGIC ]  PER Session Active: {x} (Sequencer: {s})", .{session_id[0..8].*, self.sequencer_url});
        return session;
    }

    /// Envía una transacción al secuenciador efímero.
    /// Latencia objetivo: <20ms.
    pub fn dispatchEphemeral(self: *MagicBlockSDK, session: *const Session, tx: EphemeralTx) ![]const u8 {
        if (!session.is_active or session.isExpired()) return error.SessionInvalid;

        std.debug.print("\n[MAGIC ]  Dispatching HFT Transaction to Sequencer {s}...", .{self.sequencer_url});
        
        const http_mod = @import("../mesh/http.zig");
        var client = http_mod.HttpClient.init(self.allocator);

        // Serialización del AWP Packet (Transferencia Efímera)
        var body = std.ArrayListUnmanaged(u8){};
        defer body.deinit(self.allocator);
        
        try body.writer(self.allocator).print("{any}", .{std.json.fmt(.{
            .session_id = session.id,
            .target = tx.target,
            .amount = tx.amount,
            .payload_hash = tx.payload_hash,
            .signature = tx.signature,
        }, .{})});

        var response = try client.post(self.sequencer_url, body.items);
        defer response.deinit();

        // El secuenciador devuelve la firma de aceptación en el Rollup
        return try self.allocator.dupe(u8, response.body);
    }

    /// Cierra la sesión y hace el commit final a Solana L1.
    pub fn commitToSolana(self: *MagicBlockSDK, session: *Session) !void {
        _ = self;
        std.debug.print("\n[MAGIC ]  Committing Ephemeral State to Solana L1...", .{});
        session.is_active = false;
        // Logic to trigger the sequencer's settle process...
    }
};

/// Adapter para compatibilidad con el Engine anterior.
pub const MagicBlockClient = MagicBlockSDK;
