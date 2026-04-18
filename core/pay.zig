const std = @import("std");
const types = @import("types.zig");
const vault_mod = @import("vault.zig");
const solana = @import("solana.zig");
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

pub const PaymentRouter = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    vaults: *vault_mod.VaultSet,

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, vaults: *vault_mod.VaultSet) PaymentRouter {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .vaults = vaults,
        };
    }

    pub fn pay(self: *PaymentRouter, request: PaymentRequest) !PaymentResult {
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

        // 1. Verificar Policy
        const recipient_sol = if (request.recipient == .sol) request.recipient.sol else null;
        if (!try v.canSpend(request.amount, request.asset, recipient_sol)) return error.PolicyViolation;

        // 2. Obtener Blockhash
        const blockhash = try self.sol_client.getLatestBlockhash();

        // 3. Construir Transacción
        const tx_bytes = try tx_mod.buildTransferTx(
            self.allocator,
            v.sol_kp.public,
            request.recipient.sol,
            request.amount,
            blockhash,
        );
        defer self.allocator.free(tx_bytes);

        // 4. Firmar (La firma va después del primer byte del wire format en un transfer simple)
        // El mensaje empieza en el byte 65 (1 byte de count + 64 bytes de firma placeholder)
        const message = tx_bytes[65..];
        const signature = crypto.sign(message, &v.sol_kp);
        @memcpy(tx_bytes[1..65], &signature);

        // 5. Enviar
        const sig_str = try self.sol_client.sendTransaction(tx_bytes);

        // 6. Registrar Gasto
        try v.recordSpend(request.amount, request.asset);

        return PaymentResult{
            .tx_signature = sig_str,
            .chain = .solana,
            .strategy = strategy,
            .fee_paid = 5000,
        };
    }

    fn payEVM(self: *PaymentRouter, request: PaymentRequest, strategy: PaymentStrategy) !PaymentResult {
        return PaymentResult{
            .tx_signature = try self.allocator.dupe(u8, "0xmock_evm_sig"),
            .chain = request.asset.chain,
            .strategy = strategy,
            .fee_paid = 21000,
        };
    }
};
