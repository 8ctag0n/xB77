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
    risk_scorer: audit_mod.RiskScorer,

    // Dirección de Tesorería para recolectar el Infra Overhead
    pub const TREASURY_SOL = "Dk6vYdPu3EAb2WT1amGdgYS5puTZRiRzvehBmYhzffJo"; // Agente xB77 Admin
    pub const TREASURY_EVM = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Mock treasury
    pub const INFRA_TAX_BPS = 11; // 0.11% (11 Basis Points)

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, evm_client: *evm_mod.EvmClient, vaults: *vault_mod.VaultSet) PaymentRouter {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .evm_client = evm_client,
            .vaults = vaults,
            .risk_scorer = audit_mod.RiskScorer.init(allocator),
        };
    }

    /// Calcula el costo de facilitación (0.11%)
    fn calculateInfraOverhead(self: *PaymentRouter, amount: u64) u64 {
        _ = self;
        // (Amount * 11) / 10,000 = 0.11%
        return (amount * INFRA_TAX_BPS) / 10000;
    }

    pub fn pay(self: *PaymentRouter, request: PaymentRequest) !PaymentResult {
        // 1. Auditoría de Riesgo (Risk Recon)
        if (request.recipient == .sol) {
            const report = try self.risk_scorer.assess(request.recipient.sol, request.amount);
            if (!report.passed) {
                std.debug.print("[PaymentRouter] ❌ Riesgo detectado: {s}\n", .{report.flags[0]});
                return error.RiskAuditFailed;
            }
        }

        const strategy = self.selectStrategy(request);
        
        return switch (request.asset.chain) {
            .solana => self.paySolana(request, strategy),
            .base, .arbitrum => self.payEVM(request, strategy),
        };
    }

    fn selectStrategy(self: *PaymentRouter, request: PaymentRequest) PaymentStrategy {
        _ = self;
        if (request.amount > 1_000_000_000) return .ghost;
        return .direct;
    }

    fn paySolana(self: *PaymentRouter, request: PaymentRequest, strategy: PaymentStrategy) !PaymentResult {
        const v = &self.vaults.ops;

        // 1. Calcular Tax (Infra Tax)
        const tax_amount = self.calculateInfraOverhead(request.amount);
        const total_amount = request.amount + tax_amount;

        // 2. Verificar Policy
        const recipient_sol = if (request.recipient == .sol) request.recipient.sol else null;
        if (!try v.canSpend(total_amount, request.asset, recipient_sol)) return error.PolicyViolation;

        // 3. Obtener Blockhash
        const blockhash = try self.sol_client.getLatestBlockhash();

        // 4. Preparar Transferencias
        const treasury_pubkey = try crypto.stringToPubkey(self.allocator, TREASURY_SOL);
        
        var transfers = std.ArrayListUnmanaged(tx_mod.Transfer){};
        defer transfers.deinit(self.allocator);
        
        try transfers.append(self.allocator, .{ .to = request.recipient.sol, .lamports = request.amount });
        try transfers.append(self.allocator, .{ .to = treasury_pubkey, .lamports = tax_amount });

        // 5. Construir Transacción Mult-Instrucción
        const tx_bytes = try tx_mod.buildMultiTransferTx(
            self.allocator,
            v.sol_kp.public,
            transfers.items,
            blockhash,
        );
        defer self.allocator.free(tx_bytes);

        // 6. Firmar
        const message = tx_bytes[65..];
        const signature = crypto.sign(message, &v.sol_kp);
        @memcpy(tx_bytes[1..65], &signature);

        // --- NUEVO: GENERAR ZK RECEIPT ---
        const receipt = try receipt_mod.ZkReceipt.generate(request.amount, tax_amount, request.recipient.sol);
        try receipt.writeProverToml("circuits/zk_receipt/Prover.toml");
        std.debug.print("[PaymentRouter] 🧾 ZK-Receipt Prover.toml generado en circuits/zk_receipt/\n", .{});

        // 7. Enviar
        const sig_str = try self.sol_client.sendTransaction(tx_bytes);

        // 8. Registrar Gasto
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

        // 1. Calcular Tax (Infra Tax)
        const tax_amount = self.calculateInfraOverhead(request.amount);
        const total_amount = request.amount + tax_amount;

        // 2. Verificar Policy
        if (!try v.canSpend(total_amount, request.asset, null)) return error.PolicyViolation;

        // 3. Obtener Nonce y Gas
        const nonce = try self.evm_client.getNonce(eth_kp.address);
        const gas_price = try self.evm_client.getGasPrice();

        // 4. Construir Transacción (Transferencia Simple para demo)
        const tx = tx_mod.EthEip1559Tx{
            .chain_id = 84532, // Base Sepolia
            .nonce = nonce,
            .max_priority_fee_per_gas = 1_000_000_000, // 1 Gwei
            .max_fee_per_gas = gas_price + 1_000_000_000,
            .gas_limit = 21000,
            .to = request.recipient.evm,
            .value = request.amount,
            .data = &.{},
        };

        const unsigned_tx = try tx_mod.buildEthEip1559Tx(self.allocator, tx);
        defer self.allocator.free(unsigned_tx);

        // 5. Firmar
        var hash: [32]u8 = undefined;
        crypto.Keccak256.hash(unsigned_tx, &hash, .{});
        const sig = try crypto.signEthMessage(hash, eth_kp.secret);

        // 6. Codificar Transacción Firmada (RLP: [tx_list, r, s, v])
        // Nota: El formato EIP-1559 firmado es 0x02 || rlp([chain_id, nonce, ..., y_parity, r, s])
        // Para simplificar la demo, codificamos el payload RLP completo
        
        const rlp = @import("rlp.zig");
        var list = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (list.items) |i| self.allocator.free(i);
            list.deinit(self.allocator);
        }

        try list.append(self.allocator, try rlp.encode(self.allocator, tx.chain_id));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.nonce));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.max_priority_fee_per_gas));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.max_fee_per_gas));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.gas_limit));
        try list.append(self.allocator, try rlp.encode(self.allocator, &request.recipient.evm));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.value));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.data));
        try list.append(self.allocator, try rlp.encode(self.allocator, tx.access_list));
        try list.append(self.allocator, try rlp.encode(self.allocator, sig.v));
        try list.append(self.allocator, try rlp.encode(self.allocator, &sig.r));
        try list.append(self.allocator, try rlp.encode(self.allocator, &sig.s));

        var payload = std.ArrayListUnmanaged(u8){};
        defer payload.deinit(self.allocator);
        for (list.items) |i| try payload.appendSlice(self.allocator, i);

        const encoded_list = try rlp.encodeListFixed(self.allocator, payload.items);
        defer self.allocator.free(encoded_list);

        const hex_buf = try crypto.bytesToHex(self.allocator, encoded_list);
        defer self.allocator.free(hex_buf);

        const tx_hex = try std.fmt.allocPrint(self.allocator, "0x02{s}", .{hex_buf});
        defer self.allocator.free(tx_hex);

        // 7. Enviar
        const tx_hash = try self.evm_client.sendRawTransaction(tx_hex);
        
        const hash_hex = try crypto.bytesToHex(self.allocator, &tx_hash);
        defer self.allocator.free(hash_hex);
        
        const tx_hash_str = try std.fmt.allocPrint(self.allocator, "0x{s}", .{hash_hex});

        // 8. Registrar Gasto
        try v.recordSpend(total_amount, request.asset);

        return PaymentResult{
            .tx_signature = tx_hash_str,
            .chain = request.asset.chain,
            .strategy = strategy,
            .fee_paid = (21000 * gas_price) + tax_amount,
        };
    }
};
