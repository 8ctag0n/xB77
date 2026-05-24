const std = @import("std");
const core = @import("../core.zig");
const types = core.types;
const crypto = core.crypto;
const solana_mod = @import("../chain/solana.zig");

/// MagicBlock's Delegation Program on Solana (devnet + mainnet).
/// CPI to this program is what makes a PER session show up on MagicBlock's
/// own explorer. Currently the L1 escrow path (openSovereignSession +
/// commitToSolana) targets our own xb77 program for the hackathon-window
/// deliverable; switching to MagicBlock's Delegation Program is the next
/// iteration — gated behind XB77_MAGICBLOCK_USE_DELEGATION env var so the
/// fallback escrow stays available while the Delegation CPI is being
/// validated end-to-end against their devnet.
pub const MAGICBLOCK_DELEGATION_PROGRAM_ID =
    "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh";

/// xB77's own escrow program (xb77_core). Used while the Delegation
/// Program wire is being validated.
const XB77_ESCROW_PROGRAM_ID = "73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3";

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
        const default_url = "https://devnet.magicblock.app";
        const final_url = if (url.len > 0) allocator.dupe(u8, url) catch default_url else allocator.dupe(u8, default_url) catch default_url;
        return .{
            .allocator = allocator,
            .sequencer_url = final_url,
        };
    }

    pub fn deinit(self: *MagicBlockSDK) void {
        self.allocator.free(self.sequencer_url);
    }

    /// Abre una sesión PER nativamente.
    /// Involucra una transacción on-chain inicial en Solana para bloquear el estado.
    pub fn openSovereignSession(self: *MagicBlockSDK, agent_kp: *const types.Keypair) !Session {
        std.debug.print("\n[MAGIC ] ️ Initiating Sovereign Session (PER) for Agent {x}...", .{agent_kp.public[0..4]});
        
        // Demo-Deluxe Mode: Mock session opening
        const is_demo = blk: {
            const env = std.process.getEnvVarOwned(self.allocator, "XB77_DEMO_MODE") catch break :blk false;
            defer self.allocator.free(env);
            break :blk std.mem.eql(u8, env, "1");
        };

        if (is_demo) {
            std.debug.print("\n[MAGIC ]  {s}[DEMO-DELUXE ACTIVE]{s} Mocking PER Session...", .{ "\x1b[35;1m", "\x1b[0m" });
            var session_id: [32]u8 = undefined;
            std.crypto.random.bytes(&session_id);
            return Session{
                .id = session_id,
                .authority = agent_kp.public,
                .expiry = std.time.timestamp() + 86400, // 24h for demo
                .is_active = true,
            };
        }

        // 1. Generar Session ID aleatorio
        var session_id: [32]u8 = undefined;
        std.crypto.random.bytes(&session_id);

        const expiry = std.time.timestamp() + 3600; // 1 hora de turbo

        // 2. Anclar el Escrow en Solana (L1) REAL
        if (self.sol_client) |sol| {
            // Tests use "mock:..." endpoints to short-circuit network calls.
            // Skip the L1 escrow anchor in that case; return a synthetic session.
            if (std.mem.startsWith(u8, sol.endpoint, "mock:")) {
                std.debug.print("\n[MAGIC ]  (mock endpoint — skipping L1 escrow anchor)", .{});
                return Session{
                    .id = session_id,
                    .authority = agent_kp.public,
                    .expiry = expiry,
                    .is_active = true,
                };
            }
            const tx_mod = @import("../protocol/tx.zig");
            const amount: u64 = 2_000_000_000; // 2.0 SOL hardcoded for the demo session

            std.debug.print("\n[MAGIC ]  Locking {d} lamports in L1 Escrow for Session {x}...", .{amount, session_id[0..4].*});
            
            const ix_data = try tx_mod.buildOpenPerSessionInstruction(self.allocator, amount, session_id, expiry);
            defer self.allocator.free(ix_data);

            // Toggle between xB77's own escrow program and MagicBlock's
            // Delegation Program via env. Default keeps xB77 path for
            // determinism; flipping the env routes the L1 anchor through
            // MagicBlock so sessions appear on their explorer.
            const use_delegation = blk: {
                const env = std.process.getEnvVarOwned(self.allocator, "XB77_MAGICBLOCK_USE_DELEGATION") catch break :blk false;
                defer self.allocator.free(env);
                break :blk std.mem.eql(u8, env, "1");
            };
            const program_id_str = if (use_delegation)
                MAGICBLOCK_DELEGATION_PROGRAM_ID
            else
                XB77_ESCROW_PROGRAM_ID;
            const program_id = try crypto.stringToPubkey(self.allocator, program_id_str);
            
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
        
        if (std.mem.startsWith(u8, self.sequencer_url, "mock:")) {
            return try self.allocator.dupe(u8, "{\"status\":\"ok\",\"receipt\":\"mock_magicblock_receipt_v1\"}");
        }

        const http_mod = @import("../mesh/http.zig");
        var client = http_mod.HttpClient.init(self.allocator);

        // Serialización del payload compatible con el bridge de xB77
        var body_buf = std.ArrayListUnmanaged(u8){};
        defer body_buf.deinit(self.allocator);
        
        try body_buf.writer(self.allocator).print("{f}", .{std.json.fmt(.{
            .sessionId = std.fmt.bytesToHex(session.id, .lower),
            .target = try crypto.pubkeyToString(self.allocator, &tx.target),
            .amount = tx.amount,
            .payloadHash = std.fmt.bytesToHex(tx.payload_hash, .lower),
            .signature = std.fmt.bytesToHex(tx.signature, .lower),
        }, .{})});

        var response = try client.post(self.sequencer_url, body_buf.items);
        defer response.deinit();

        if (response.status != 200) {
            std.debug.print("\n[MAGIC ]  Sequencer Error: {d} - {s}", .{response.status, response.body});
            return error.SequencerError;
        }

        // El secuenciador devuelve la firma de aceptación o un receipt JSON
        return try self.allocator.dupe(u8, response.body);
    }

    /// Cierra la sesión y hace el commit final a Solana L1.
    pub fn commitToSolana(self: *MagicBlockSDK, session: *Session, agent_kp: *const types.Keypair) !void {
        std.debug.print("\n[MAGIC ]  Committing Ephemeral State to Solana L1 for Session {x}...", .{session.id[0..4].*});
        
        if (self.sol_client) |sol| {
            if (std.mem.startsWith(u8, sol.endpoint, "mock:")) {
                session.is_active = false;
                return;
            }

            const tx_mod = @import("../protocol/tx.zig");
            const ix_data = try tx_mod.buildClosePerSessionInstruction(self.allocator, session.id);
            defer self.allocator.free(ix_data);

            // Toggle between xB77's own escrow program and MagicBlock's
            // Delegation Program via env. Default keeps xB77 path for
            // determinism; flipping the env routes the L1 anchor through
            // MagicBlock so sessions appear on their explorer.
            const use_delegation = blk: {
                const env = std.process.getEnvVarOwned(self.allocator, "XB77_MAGICBLOCK_USE_DELEGATION") catch break :blk false;
                defer self.allocator.free(env);
                break :blk std.mem.eql(u8, env, "1");
            };
            const program_id_str = if (use_delegation)
                MAGICBLOCK_DELEGATION_PROGRAM_ID
            else
                XB77_ESCROW_PROGRAM_ID;
            const program_id = try crypto.stringToPubkey(self.allocator, program_id_str);
            
            // PDA del Escrow: [b"per_escrow", agent_pubkey, session_id]
            var seeds = [_][]const u8{ "per_escrow", &agent_kp.public, &session.id };
            const pda_res = try crypto.findProgramAddress(&seeds, &program_id);
            
            const blockhash = try sol.getLatestBlockhash();
            
            var buf = std.ArrayListUnmanaged(u8){};
            defer buf.deinit(self.allocator);
            const writer = buf.writer(self.allocator);

            try tx_mod.writeCompactU16(writer, 1);
            try buf.appendNTimes(self.allocator, 0, 64);
            
            const message_start = buf.items.len;
            try writer.writeByte(1); // num_sigs
            try writer.writeByte(0); // num_signed_readonly
            try writer.writeByte(1); // num_unsigned_readonly (program)
            
            try tx_mod.writeCompactU16(writer, 3); // signer, pda, program
            try buf.appendSlice(self.allocator, &agent_kp.public);
            try buf.appendSlice(self.allocator, &pda_res.address);
            try buf.appendSlice(self.allocator, &program_id);
            
            try buf.appendSlice(self.allocator, &blockhash);
            
            try tx_mod.writeCompactU16(writer, 1);
            try writer.writeByte(2); // program_id index
            try tx_mod.writeCompactU16(writer, 2); // 2 accounts
            try writer.writeByte(0); // signer
            try writer.writeByte(1); // escrow pda
            
            try tx_mod.writeCompactU16(writer, @intCast(ix_data.len));
            try buf.appendSlice(self.allocator, ix_data);

            const message = buf.items[message_start..];
            const signature = crypto.sign(message, agent_kp);
            @memcpy(buf.items[1..65], &signature);

            const sig = try sol.sendTransaction(buf.items);
            std.debug.print("\n[MAGIC ]  L1 Settlement Complete. Sig: {s}", .{sig});
            self.allocator.free(sig);
        }

        session.is_active = false;
    }
};

/// Adapter para compatibilidad con el Engine anterior.
pub const MagicBlockClient = MagicBlockSDK;
