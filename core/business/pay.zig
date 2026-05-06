const std = @import("std");
const types = @import("../protocol/types.zig");
const vault_mod = @import("../state/vault.zig");
const solana = @import("../chain/solana.zig");
const evm_mod = @import("../chain/evm.zig");
const tx_mod = @import("../protocol/tx.zig");
const crypto = @import("../crypto/crypto.zig");

pub const PaymentStrategy = enum {
    direct,
    ghost,
    obfuscated,
};

pub const PaymentRequest = struct {
    amount: u64,
    asset: types.Asset,
    recipient: union(enum) {
        sol: types.Pubkey,
        evm: types.EthAddress,
    },
};

pub const PaymentResult = struct {
    tx_signature: []const u8,
    chain: types.Chain,
    strategy: PaymentStrategy,
    fee_paid: u64,
};

pub const BatchInstruction = struct {
    to: []const u8,
    amount: u64,
    chain: types.Chain = .solana,
    symbol: []const u8 = "SOL",
};

const audit_mod = @import("../business/audit.zig");
const receipt_mod = @import("../business/receipt.zig");

pub const PaymentRouter = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    evm_client: *evm_mod.EvmClient,
    vaults: *vault_mod.VaultSet,
    store: *@import("../state/store.zig").Store,
    constitution: *@import("../business/constitution.zig").Constitution,
    risk_scorer: audit_mod.RiskScorer,
    facilitator: ?[]const u8,

    pub const INFRA_TAX_BPS = 2011; // 2.011% (dividir por 100000)

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, evm_client: *evm_mod.EvmClient, vaults: *vault_mod.VaultSet, store_ptr: *@import("../state/store.zig").Store, constitution: *@import("../business/constitution.zig").Constitution, facilitator: ?[]const u8) PaymentRouter {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .evm_client = evm_client,
            .vaults = vaults,
            .store = store_ptr,
            .constitution = constitution,
            .risk_scorer = audit_mod.RiskScorer.init(allocator),
            .facilitator = facilitator,
        };
    }

    /// Calcula el costo de facilitación (2.011%)
    fn calculateInfraOverhead(self: *PaymentRouter, amount: u64) u64 {
        _ = self;
        return (amount * INFRA_TAX_BPS) / 100000;
    }

    pub fn pay(self: *PaymentRouter, request: PaymentRequest) !PaymentResult {
        // 1. Auditoría de Riesgo (Risk Recon)
        const audit_recipient = switch (request.recipient) {
            .sol => |pk| audit_mod.RiskScorer.Recipient{ .sol = pk },
            .evm => |addr| audit_mod.RiskScorer.Recipient{ .evm = addr },
        };
        
        const report = try self.risk_scorer.assess(audit_recipient, request.amount);
        if (!report.passed) {
            std.debug.print("[PaymentRouter] Risk detected: {s}\n", .{report.flags[0]});
            return error.RiskAuditFailed;
        }

        // 2. Selección de estrategia y ruteo multichain
        const strategy = self.selectStrategy(request);
        
        // Decidir cadena basada en el asset o disponibilidad
        const target_chain = self.route(request);
        
        return switch (target_chain) {
            .solana => self.paySolana(request, strategy),
            .base, .arbitrum => self.payEVM(request, strategy),
            else => error.UnsupportedChain,
        };
    }

    pub fn lockFunds(self: *PaymentRouter, hire_id: [32]u8, amount: u64, asset: types.Asset) ![]const u8 {
        _ = hire_id;
        std.debug.print("[APP] Locking {d} {s} for Hire (MagicBlock Ephemeral Escrow)\n", .{
            amount, asset.symbol
        });
        
        // Evitar llamadas reales a la red durante tests si el endpoint es mock
        if (std.mem.startsWith(u8, self.sol_client.endpoint, "mock:")) {
            return try self.allocator.dupe(u8, "mock_escrow_sig_5ov3r31gn");
        }

        // En un caso real, esto enviaría los fondos al programa de Escrow de MagicBlock.
        // Por ahora lo ruteamos a una dirección de Escrow Soberana.
        const escrow_pk = try crypto.stringToPubkey(self.allocator, "11111111111111111111111111111111");
        
        const request = PaymentRequest{
            .amount = amount,
            .asset = asset,
            .recipient = .{ .sol = escrow_pk },
        };
        
        const res = try self.pay(request);
        return res.tx_signature;
    }

    pub fn releaseFunds(self: *PaymentRouter, hire_id: [32]u8, recipient: types.Pubkey) ![]const u8 {
        _ = hire_id;
        _ = recipient;
        std.debug.print("[APP] Releasing Escrow for Hire to recipient\n", .{});
        
        // Mock de liberación exitosa
        return try self.allocator.dupe(u8, "5ov3r31gn_r3l3453_516");
    }

    pub fn asAppRouter(self: *PaymentRouter) @import("app.zig").IAppRouter {
        return .{
            .ptr = self,
            .lockFundsFn = struct {
                fn lock(ptr: *anyopaque, hire_id: [32]u8, amount: u64, asset: types.Asset) ![]const u8 {
                    const self_ptr: *PaymentRouter = @ptrCast(@alignCast(ptr));
                    return self_ptr.lockFunds(hire_id, amount, asset);
                }
            }.lock,
        };
    }

    pub fn processBatch(self: *PaymentRouter, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB limit
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');

        std.debug.print("\n Starting Deluxe Batch Processing: {s}\n", .{file_path});
        var count: usize = 0;
        var success_count: usize = 0;

        while (lines.next()) |line| {
            if (line.len == 0) continue;
            count += 1;

            const instr_parsed = std.json.parseFromSlice(BatchInstruction, self.allocator, line, .{ .ignore_unknown_fields = true }) catch |err| {
                std.debug.print(" Line {d}: Parse error: {}\n", .{count, err});
                continue;
            };
            defer instr_parsed.deinit();
            const instr = instr_parsed.value;

            std.debug.print(" [{d}] Processing {d} {s} to {s}...", .{count, instr.amount, instr.symbol, instr.to[0..8]});

            // Convertir instrucción a PaymentRequest
            const req = if (instr.chain == .solana) blk: {
                const pk = crypto.stringToPubkey(self.allocator, instr.to) catch {
                    std.debug.print(" Invalid Address\n", .{});
                    continue;
                };
                break :blk PaymentRequest{
                    .amount = instr.amount,
                    .asset = .{ .chain = .solana, .symbol = instr.symbol },
                    .recipient = .{ .sol = pk },
                };
            } else blk: {
                const addr = evm_mod.hexToAddress(instr.to) catch {
                    std.debug.print(" Invalid Address\n", .{});
                    continue;
                };
                break :blk PaymentRequest{
                    .amount = instr.amount,
                    .asset = .{ .chain = .base, .symbol = instr.symbol },
                    .recipient = .{ .evm = addr },
                };
            };

            const result = self.pay(req) catch |err| {
                std.debug.print(" FAILED: {}\n", .{err});
                continue;
            };

            const sig_short = if (result.tx_signature.len > 12) result.tx_signature[0..12] else result.tx_signature;
            std.debug.print(" OK! {s}\n", .{sig_short});
            success_count += 1;
        }

        std.debug.print("\n Batch Finished: {d}/{d} transactions successful.\n", .{success_count, count});
    }

    fn route(self: *PaymentRouter, request: PaymentRequest) types.Chain {
        _ = self;
        return request.asset.chain;
    }

    fn selectStrategy(self: *PaymentRouter, request: PaymentRequest) PaymentStrategy {
        _ = self;
        
        // Institutional Policy: High-value transfers trigger enhanced privacy rails.
        if (std.mem.eql(u8, request.asset.symbol, "USDT") or std.mem.eql(u8, request.asset.symbol, "Tether")) {
             if (request.amount > 5_000_000_000) {
                 std.debug.print("[Strategy] Activating Tether Corporate Privacy Shield for high-value transfer\n", .{});
                 return .ghost;
             }
        }

        if (request.amount > 1_000_000_000) {
            std.debug.print("[Strategy] Routing through privacy rail due to amount threshold\n", .{});
            return .ghost;
        }
        return .direct;
    }

    fn paySolana(self: *PaymentRouter, request: PaymentRequest, strategy: PaymentStrategy) !PaymentResult {
        const v = &self.vaults.ops;

        const tax_amount = self.calculateInfraOverhead(request.amount);
        const total_amount = request.amount + tax_amount;

        // --- JUICIO CONSTITUCIONAL (Router as Judge) ---
        const addr_str = try crypto.pubkeyToString(self.allocator, &request.recipient.sol);
        defer self.allocator.free(addr_str);

        if (!self.constitution.isActionAllowed(addr_str)) {
            std.debug.print("[PaymentRouter] Blocked by Constitution: {s}\n", .{addr_str});
            return error.ConstitutionalViolation;
        }

        // --- LÍMITES FÍSICOS (Vault as Keeper) ---
        if (!try v.canSpend(total_amount, request.asset, addr_str)) return error.PolicyViolation;
        // -----------------------------------------------

        if (strategy == .ghost) {
            std.debug.print("\n[GHOST ] 👻 Activating Ghost Strategy for {d} lamports.", .{request.amount});
            std.debug.print("\n[GHOST ]  Recording sovereign state change (Zero-Knowledge Sync)...", .{});
            
            // 1. Registrar en el Store Soberano (Actualiza el CMT local)
            // Usamos un entry_type específico para que el Sequencer lo procese
            const store_mod = @import("../state/store.zig");
            const entry = store_mod.LedgerEntry{
                .timestamp = std.time.milliTimestamp(),
                .chain = .solana,
                .entry_type = .receipt,
                .description = "Ghost Payment Settlement",
                .amount = request.amount,
                .tx_hash = "zk_ghost_pending",
            };
            
            // Acceso al store vía el AgentContext (usamos un truco de casting o pasamos el store)
            // Por ahora, asumimos que el router tiene acceso a la estructura que contiene el store
            // En este caso, el store está en ctx, pero el router no tiene ctx.
            // Vamos a pasar el store al Router en init.
            try self.store.record(entry);

            try v.recordSpend(total_amount, request.asset);

            return PaymentResult{
                .tx_signature = "ghost_settlement_queued",
                .chain = .solana,
                .strategy = .ghost,
                .fee_paid = tax_amount,
            };
        }

        const blockhash = try self.sol_client.getLatestBlockhash();
        
        // --- ROUTING: NATIVE vs TOKEN ---
        var sig_str: []const u8 = undefined;
        if (std.mem.eql(u8, request.asset.symbol, "SOL")) {
            const addresses = [_][]const u8{"11111111111111111111111111111111"};
            const priority_fee = self.sol_client.getRecentPrioritizationFees(&addresses) catch 0;

            var transfers = std.ArrayListUnmanaged(tx_mod.Transfer){};
            defer transfers.deinit(self.allocator);
            try transfers.append(self.allocator, .{ .to = request.recipient.sol, .lamports = request.amount });

            const fac_pubkey = if (self.facilitator) |f| try crypto.stringToPubkey(self.allocator, f) else null;

            const tx_bytes = try tx_mod.buildMultiTransferTx(
                self.allocator,
                v.sol_kp.public,
                transfers.items,
                blockhash,
                priority_fee,
                fac_pubkey,
            );
            defer self.allocator.free(tx_bytes);

            const message = tx_bytes[65..];
            const signature = crypto.sign(message, &v.sol_kp);
            @memcpy(tx_bytes[1..65], &signature);

            try self.sol_client.simulateTransaction(tx_bytes);
            sig_str = try self.sol_client.sendTransaction(tx_bytes);
        } else {
            // SPL Token Transfer (USDT, etc.)
            const mint_addr = request.asset.address orelse blk: {
                if (std.mem.eql(u8, request.asset.symbol, "USDT")) {
                    break :blk try crypto.stringToPubkey(self.allocator, types.Asset.USDT_SOL);
                } else return error.MissingTokenAddress;
            };

            // Para el demo, simulamos las ATAs (en producción usaríamos getAssociatedTokenAddress)
            const source_ata = v.sol_kp.public; // MOCK
            const dest_ata = request.recipient.sol; // MOCK

            const tx_bytes = try tx_mod.buildSplTransferTx(
                self.allocator,
                v.sol_kp.public,
                mint_addr,
                source_ata,
                dest_ata,
                request.amount,
                blockhash,
            );
            defer self.allocator.free(tx_bytes);

            const message = tx_bytes[65..];
            const signature = crypto.sign(message, &v.sol_kp);
            @memcpy(tx_bytes[1..65], &signature);

            sig_str = try self.sol_client.sendTransaction(tx_bytes);
        }

        const receipt = try receipt_mod.ZkReceipt.generate(request.amount, tax_amount, .{ .sol = request.recipient.sol });
        try receipt.writeProverToml("circuits/zk_receipt/Prover.toml");

        try v.recordSpend(total_amount, request.asset);

        return PaymentResult{
            .tx_signature = sig_str,
            .chain = .solana,
            .strategy = strategy,
            .fee_paid = 5000 + tax_amount,
        };
    }

    fn payEVM(self: *PaymentRouter, request: PaymentRequest, strategy: PaymentStrategy) !PaymentResult {
        const v = &self.vaults.ops;
        const eth_kp = v.eth_kp orelse return error.EthKeypairNotInitialized;

        const tax_amount = self.calculateInfraOverhead(request.amount);
        const total_amount = request.amount + tax_amount;

        // --- JUICIO CONSTITUCIONAL (Router as Judge) ---
        const addr_str = try evm_mod.addressToHex(self.allocator, request.recipient.evm);
        defer self.allocator.free(addr_str);

        if (!self.constitution.isActionAllowed(addr_str)) {
            std.debug.print("[PaymentRouter] Blocked by Constitution: {s}\n", .{addr_str});
            return error.ConstitutionalViolation;
        }

        // --- LÍMITES FÍSICOS (Vault as Keeper) ---
        if (!try v.canSpend(total_amount, request.asset, addr_str)) return error.PolicyViolation;
        // -----------------------------------------------

        var nonce = try self.evm_client.getNonce(eth_kp.address);
        const gas_price = try self.evm_client.getGasPrice();

        const tx = tx_mod.EthEip1559Tx{
            .chain_id = 84532, // Base Sepolia
            .nonce = nonce,
            .max_priority_fee_per_gas = 1_000_000_000, 
            .max_fee_per_gas = gas_price + 1_000_000_000,
            .gas_limit = 21000,
            .to = request.recipient.evm,
            .value = request.amount,
            .data = &.{},
        };

        const signed_tx = try tx_mod.buildEthEip1559Tx(self.allocator, tx, &eth_kp);
        defer self.allocator.free(signed_tx);

        const tx_hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{try crypto.bytesToHex(self.allocator, signed_tx)});
        defer self.allocator.free(tx_hex);

        const tx_hash = try self.evm_client.sendRawTransaction(tx_hex);
        
        const receipt = try receipt_mod.ZkReceipt.generate(request.amount, tax_amount, .{ .evm = request.recipient.evm });
        try receipt.writeProverToml("circuits/zk_receipt/Prover.toml");

        if (self.facilitator != null and tax_amount > 0) {
            nonce += 1;
            const fac_addr = try evm_mod.hexToAddress(self.facilitator.?);
            
            const tax_tx = tx_mod.EthEip1559Tx{
                .chain_id = 84532,
                .nonce = nonce,
                .max_priority_fee_per_gas = 1_000_000_000,
                .max_fee_per_gas = gas_price + 1_000_000_000,
                .gas_limit = 21000,
                .to = fac_addr,
                .value = tax_amount,
                .data = &.{},
            };

            const signed_tax_tx = try tx_mod.buildEthEip1559Tx(self.allocator, tax_tx, &eth_kp);
            defer self.allocator.free(signed_tax_tx);

            const tax_tx_hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{try crypto.bytesToHex(self.allocator, signed_tax_tx)});
            defer self.allocator.free(tax_tx_hex);

            _ = try self.evm_client.sendRawTransaction(tax_tx_hex);
        }

        const hash_hex = try crypto.bytesToHex(self.allocator, &tx_hash);
        defer self.allocator.free(hash_hex);
        const tx_hash_str = try std.fmt.allocPrint(self.allocator, "0x{s}", .{hash_hex});

        try v.recordSpend(total_amount, request.asset);

        return PaymentResult{
            .tx_signature = tx_hash_str,
            .chain = request.asset.chain,
            .strategy = strategy,
            .fee_paid = (21000 * gas_price * (if (self.facilitator != null) @as(u64, 2) else 1)) + tax_amount,
        };
    }
};
