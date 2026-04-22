const std = @import("std");
const types = @import("types.zig");
const vault_mod = @import("vault.zig");
const solana = @import("solana.zig");
const evm_mod = @import("evm.zig");
const tx_mod = @import("tx.zig");
const crypto = @import("crypto.zig");

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

const audit_mod = @import("audit.zig");
const receipt_mod = @import("receipt.zig");

pub const PaymentRouter = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    evm_client: *evm_mod.EvmClient,
    vaults: *vault_mod.VaultSet,
    constitution: *const @import("constitution.zig").Constitution,
    risk_scorer: audit_mod.RiskScorer,
    facilitator: ?[]const u8,

    pub const INFRA_TAX_BPS = 1100; // 11% (1100 Basis Points)

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, evm_client: *evm_mod.EvmClient, vaults: *vault_mod.VaultSet, constitution: *const @import("constitution.zig").Constitution, facilitator: ?[]const u8) PaymentRouter {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .evm_client = evm_client,
            .vaults = vaults,
            .constitution = constitution,
            .risk_scorer = audit_mod.RiskScorer.init(allocator),
            .facilitator = facilitator,
        };
    }

    /// Calcula el costo de facilitación (0.11%)
    fn calculateInfraOverhead(self: *PaymentRouter, amount: u64) u64 {
        _ = self;
        return (amount * INFRA_TAX_BPS) / 10000;
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
        };
    }

    /// Lógica de ruteo inteligente
    fn route(self: *PaymentRouter, request: PaymentRequest) types.Chain {
        _ = self;
        // Si el request pide una cadena específica, la respetamos.
        // Pero si es un activo multichain (ej: USDC), podríamos elegir aquí.
        // Por ahora, usamos la cadena del activo solicitado.
        return request.asset.chain;
    }

    fn selectStrategy(self: *PaymentRouter, request: PaymentRequest) PaymentStrategy {
        _ = self;
        if (request.amount > 1_000_000_000) return .ghost;
        return .direct;
    }

    fn paySolana(self: *PaymentRouter, request: PaymentRequest, strategy: PaymentStrategy) !PaymentResult {
        const v = &self.vaults.ops;

        const tax_amount = self.calculateInfraOverhead(request.amount);
        const total_amount = request.amount + tax_amount;

        const recipient = vault_mod.Recipient{ .sol = request.recipient.sol };
        if (!try v.canSpend(self.constitution, total_amount, request.asset, recipient)) return error.PolicyViolation;

        const blockhash = try self.sol_client.getLatestBlockhash();
        
        const addresses = [_][]const u8{"11111111111111111111111111111111"};
        const priority_fee = self.sol_client.getRecentPrioritizationFees(&addresses) catch 0;
        std.debug.print("[PaymentRouter] HFT: Applying Priority Fee of {d} micro-lamports\n", .{priority_fee});

        var transfers = std.ArrayListUnmanaged(tx_mod.Transfer){};
        defer transfers.deinit(self.allocator);
        
        try transfers.append(self.allocator, .{ .to = request.recipient.sol, .lamports = request.amount });
        // NOTE: We don't manually append the tax transfer here anymore, buildMultiTransferTx handles it.

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

        const receipt = try receipt_mod.ZkReceipt.generate(request.amount, tax_amount, request.recipient.sol);
        try receipt.writeProverToml("circuits/zk_receipt/Prover.toml");
        std.debug.print("[PaymentRouter] ZK-Receipt Prover.toml generated\n", .{});

        const sig_str = try self.sol_client.sendTransaction(tx_bytes);
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

        const recipient = vault_mod.Recipient{ .evm = request.recipient.evm };
        if (!try v.canSpend(self.constitution, total_amount, request.asset, recipient)) return error.PolicyViolation;

        var nonce = try self.evm_client.getNonce(eth_kp.address);
        const gas_price = try self.evm_client.getGasPrice();

        // 1. Pago Principal
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
        
        // 2. Pago de Infra Tax (si hay facilitador)
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
            std.debug.print("[PaymentRouter] EVM 11% Infra Tax sent to {s}\n", .{self.facilitator.?});
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
