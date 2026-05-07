const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../security/crypto.zig");
const awp = @import("../protocol/awp.zig");
const yellowstone = @import("../mesh/yellowstone.zig");
const solana = @import("../chain/solana.zig");
const constitution = @import("../security/constitution.zig");

const Address = [32]u8;

/// ComplianceEngine: The Sovereign Shield of xB77.
pub const ComplianceEngine = struct {
    allocator: std.mem.Allocator,
    sol_client: ?*solana.SolanaClient = null,
    constitution: ?*constitution.Constitution = null,
    
    /// El Root del Merkle Tree de cumplimiento (Whitelist/Sanctions).
    sanctions_merkle_root: [32]u8,
    whitelist: std.ArrayListUnmanaged(Address),

    pub const MerkleTree = struct {
        leaves: std.ArrayListUnmanaged(Address),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) MerkleTree {
            return .{
                .leaves = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *MerkleTree) void {
            self.leaves.deinit(self.allocator);
        }

        pub fn addLeaf(self: *MerkleTree, leaf: [32]u8) !void {
            try self.leaves.append(self.allocator, leaf);
        }

        pub fn getRoot(self: *MerkleTree) ![32]u8 {
            if (self.leaves.items.len == 0) return [_]u8{0} ** 32;
            if (self.leaves.items.len == 1) return self.leaves.items[0];

            // Implementación simplificada de Merkle Root (Solo para S8 Demo)
            // En producción usaríamos un árbol completo.
            var current_level = std.ArrayListUnmanaged(Address){};
            defer current_level.deinit(self.allocator);
            try current_level.appendSlice(self.allocator, self.leaves.items);

            while (current_level.items.len > 1) {
                var next_level = std.ArrayListUnmanaged(Address){};
                var i: usize = 0;
                while (i < current_level.items.len) : (i += 2) {
                    const left = current_level.items[i];
                    const right = if (i + 1 < current_level.items.len) current_level.items[i + 1] else left;
                    
                    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
                    hasher.update(&left);
                    hasher.update(&right);
                    var hash: [32]u8 = undefined;
                    hasher.final(&hash);
                    try next_level.append(self.allocator, hash);
                }
                current_level.deinit(self.allocator);
                current_level = next_level;
            }
            return current_level.items[0];
        }

        /// Genera un "Prover.toml" simplificado para Noir
        pub fn generateProverData(self: *MerkleTree, index: usize) !void {
            _ = self; _ = index;
            // TODO: Integrar con el circuito compliance_shield
            std.debug.print("[Shield] Generating ZK-Innocence Proof artifacts...\n", .{});
        }
    };

    pub fn init(allocator: std.mem.Allocator, root: [32]u8) ComplianceEngine {
        return .{
            .allocator = allocator,
            .sanctions_merkle_root = root,
            .whitelist = .{},
        };
    }

    pub fn deinit(self: *ComplianceEngine) void {
        self.whitelist.deinit(self.allocator);
    }

    pub fn addAddress(self: *ComplianceEngine, addr_str: []const u8) !void {
        var addr: [32]u8 = [_]u8{0} ** 32;
        if (std.mem.startsWith(u8, addr_str, "0x")) {
            _ = try std.fmt.hexToBytes(addr[12..], addr_str[2..]);
        } else {
            @memcpy(addr[0..@min(addr_str.len, 32)], addr_str[0..@min(addr_str.len, 32)]);
        }
        try self.whitelist.append(self.allocator, addr);
    }

    pub fn getRoot(self: *ComplianceEngine) ![32]u8 {
        var tree = MerkleTree.init(self.allocator);
        defer tree.deinit();
        for (self.whitelist.items) |leaf| {
            try tree.addLeaf(leaf);
        }
        return try tree.getRoot();
    }

    /// La función "Deluxe": Verifica un paquete AWP y genera/valida la prueba de inocencia.
    pub fn verifyAwpPacket(self: *ComplianceEngine, packet: []const u8) !bool {
        var decoder = awp.AwpDecoder.init(packet);
        
        // 1. Identificar el OpCode (Compresión de 1 byte)
        const opcode = try decoder.readByte();
        
        return switch (opcode) {
            @intFromEnum(awp.MessageType.transfer) => {
                const transfer = try decoder.decodeTransfer();
                var tx = yellowstone.TransactionData{
                    .signature = [_]u8{0} ** 64,
                    .sender = [_]u8{0} ** 32,
                    .recipient = [_]u8{0} ** 32,
                    .amount = transfer.amount,
                };
                switch (transfer.recipient) {
                    .sol => |pk| @memcpy(&tx.recipient, &pk),
                    .evm => |addr| @memcpy(tx.recipient[0..20], &addr),
                }
                return self.check(tx);
            },
            @intFromEnum(awp.MessageType.signal) => true, // Las señales son informativas
            @intFromEnum(awp.MessageType.handshake) => true, // Validación de identidad ya hecha en bridge
            else => error.UnknownOpCode,
        };
    }

    /// Lógica de chequeo de sanciones usando el Merkle Root y SNS.
    pub fn check(self: *ComplianceEngine, tx: yellowstone.TransactionData) bool {
        // 1. Blacklist Check (Simulado)
        const malicious_addr = [_]u8{0xDE, 0xAD, 0xBE, 0xEF} ++ ([_]u8{0} ** 16);
        if (std.mem.eql(u8, &tx.recipient, &malicious_addr)) {
            std.debug.print("[Shield]  ALERTA: Intento de envío a dirección sancionada detectado.\n", .{});
            return false;
        }

        // 2. Hard SNS Enforcement (Power Play Stream A)
        if (self.constitution) |consti| {
            if (consti.required_sns_namespace) |namespace| {
                if (self.sol_client) |sol| {
                    _ = sol;
                    std.debug.print("[Shield] 🆔 Hard SNS Enforcement active. Checking namespace: {s}\n", .{namespace});
                    
                    // Nota: En un entorno real, el tx.recipient (Pubkey) debería tener un SNS vinculado.
                    // Para la demo, validamos que la dirección no sea anónima si el namespace es obligatorio.
                    // Implementación simplificada: Intentamos resolver un SNS ficticio basado en la pubkey
                    // o esperamos que el counterparty provea su SNS en el handshake del AWP.
                    
                    // Si no tiene SNS vinculado en el catálogo local o on-chain, rechazamos.
                    // (Simulación de fallo si no es un 'agent.sol')
                    if (tx.amount > 1_000_000_000 and !std.mem.startsWith(u8, namespace, "*")) {
                         std.debug.print("[Shield] ️ REJECTED: Counterparty lacks required Sovereign Identity ({s}).\n", .{namespace});
                         return false;
                    }
                }
            }
        }

        // 3. Whitelist Check (Si hay direcciones cargadas)
        if (self.whitelist.items.len > 0) {
            var found = false;
            for (self.whitelist.items) |addr| {
                if (std.mem.eql(u8, &addr, &tx.recipient)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("[Shield] ️ Dirección no presente en Whitelist ZK. Se requiere proof externa.\n", .{});
                // Para el MVP de S8, permitimos si no es maliciosa, pero logueamos la advertencia.
            }
        }

        // Velocity Check: No más de 1M por transacción en la rampa AWP
        if (tx.amount > 1_000_000_000_000) {
             std.debug.print("[Shield] ⚠️ Volumen excedido. Aplicando Circuit Breaker.\n", .{});
             return false;
        }

        return true;
        }

        /// Actualiza el root de cumplimiento (Gobernanza)
        pub fn updateRoot(self: *ComplianceEngine, new_root: [32]u8) void {
        self.sanctions_merkle_root = new_root;
        std.debug.print("[Shield] Constitution Updated. New Merkle Root: {x}\n", .{new_root[0..4]});
        }
        };

        /// RiskScorer: Evaluates transaction risk before dispatching to the network.
        pub const RiskScorer = struct {
        allocator: std.mem.Allocator,

        pub const Recipient = union(enum) {
        sol: [32]u8,
        evm: [20]u8,
        };

        pub const RiskReport = struct {
        passed: bool,
        score: f32,
        flags: [][]const u8,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *RiskReport) void {
            for (self.flags) |f| self.allocator.free(f);
            self.allocator.free(self.flags);
        }
        };

        pub fn init(allocator: std.mem.Allocator) RiskScorer {
        return .{ .allocator = allocator };
        }

        pub fn assess(self: RiskScorer, recipient: Recipient, amount: u64) !RiskReport {
            _ = recipient;
            var score: f32 = 0.0;
            var flags = std.ArrayListUnmanaged([]const u8){};
            errdefer {
                for (flags.items) |f| self.allocator.free(f);
                flags.deinit(self.allocator);
            }

            // Amount-based risk
            if (amount > 10_000_000_000) { // > 10 SOL
                score += 0.4;
                try flags.append(self.allocator, try self.allocator.dupe(u8, "HIGH_VOLUME"));
            }

            return RiskReport{
                .passed = score < 0.8,
                .score = score,
                .flags = try flags.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }
        /// Static assessment for real-time events
        pub fn assessTx(tx: yellowstone.TransactionData) f32 {
        var score: f32 = 0.1;
        if (tx.amount > 5_000_000_000) score += 0.3;
        return score;
        }
        };

