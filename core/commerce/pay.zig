const std = @import("std");
const types = @import("../protocol/types.zig");
const vault_mod = @import("../security/vault.zig");
const solana = @import("../chain/solana.zig");
const evm_mod = @import("../chain/evm.zig");
const tx_mod = @import("../protocol/tx.zig");
const crypto = @import("../security/crypto.zig");
const shield_mod = @import("../security/shield.zig");
const receipt_mod = @import("../commerce/receipt.zig");
const mb_mod = @import("../chain/magicblock.zig");

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
    evm_client: *evm_mod.EvmClient,
    mb_client: *mb_mod.MagicBlockClient,
    vaults: *vault_mod.VaultSet,
    store: *@import("../protocol/store.zig").Store,
    constitution: *@import("../security/constitution.zig").Constitution,
    risk_scorer: shield_mod.RiskScorer,
    facilitator: ?[]const u8,
    mb_session: ?mb_mod.MagicBlockClient.Session = null,

    // --- Guardian Mode Integration ---
    pending_auth_ptr: ?*anyopaque = null,
    pending_auth_fn: ?*const fn (ptr: *anyopaque, request: PaymentRequest, desc: []const u8) anyerror!void = null,

    pub const INFRA_TAX_BPS = 2011; // 2.011%

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, evm_client: *evm_mod.EvmClient, mb_client: *mb_mod.MagicBlockClient, vaults: *vault_mod.VaultSet, store_ptr: *@import("../protocol/store.zig").Store, constitution: *@import("../security/constitution.zig").Constitution, facilitator: ?[]const u8) PaymentRouter {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .evm_client = evm_client,
            .mb_client = mb_client,
            .vaults = vaults,
            .store = store_ptr,
            .constitution = constitution,
            .risk_scorer = shield_mod.RiskScorer.init(allocator),
            .facilitator = facilitator,
        };
    }

    fn calculateInfraOverhead(self: *PaymentRouter, amount: u64) u64 {
        _ = self;
        // bps / 100000 -> 2011 / 100000 = 0.02011 (2.011%)
        return (amount * INFRA_TAX_BPS) / 100000;
    }

    pub fn pay(self: *PaymentRouter, request: PaymentRequest) !PaymentResult {
        const audit_recipient = switch (request.recipient) {
            .sol => |pk| shield_mod.RiskScorer.Recipient{ .sol = pk },
            .evm => |addr| shield_mod.RiskScorer.Recipient{ .evm = addr },
        };
        
        var report = try self.risk_scorer.assess(audit_recipient, request.amount);
        defer report.deinit();

        if (!report.passed) return error.RiskAuditFailed;

        // --- Guardian Mode: Value Threshold Check ---
        if (request.amount > self.constitution.guardian_threshold_lamports) {
            if (self.pending_auth_fn) |auth_fn| {
                if (self.pending_auth_ptr) |ptr| {
                    try auth_fn(ptr, request, "High Value Transaction - Guardian Approval Required");
                    return error.GuardianApprovalRequired;
                }
            }
        }

        const strategy = self.selectStrategy(request);
        
        return switch (request.asset.chain) {
            .solana => self.paySolana(request, strategy),
            .base, .arbitrum => self.payEVM(request, strategy),
            else => error.UnsupportedChain,
        };
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

        const addr_str = try crypto.pubkeyToString(self.allocator, &request.recipient.sol);
        defer self.allocator.free(addr_str);

        if (!self.constitution.isActionAllowed(addr_str)) return error.ConstitutionalViolation;
        if (!try v.canSpend(total_amount, request.asset, addr_str)) return error.PolicyViolation;

        if (strategy == .ghost) {
            var mb_sig: ?[]const u8 = null;
            if (self.mb_session) |*session| {
                if (!session.isExpired()) {
                    const eph_tx = mb_mod.MagicBlockSDK.EphemeralTx{
                        .target = request.recipient.sol,
                        .amount = request.amount,
                        .payload_hash = [_]u8{0} ** 32,
                        .signature = [_]u8{0} ** 64,
                    };
                    mb_sig = try self.mb_client.dispatchEphemeral(session, eph_tx);
                }
            }
            
            try self.store.record(.{
                .timestamp = std.time.milliTimestamp(),
                .chain = .solana,
                .entry_type = .receipt,
                .description = if (mb_sig != null) "ShadowWire HFT Payment" else "Ghost Payment Settlement",
                .amount = request.amount,
                .tx_hash = if (mb_sig) |s| s else "zk_ghost_pending",
            });
            try v.recordSpend(total_amount, request.asset);

            return PaymentResult{
                .tx_signature = if (mb_sig) |s| s else "ghost_settlement_queued",
                .chain = .solana,
                .strategy = .ghost,
                .fee_paid = tax_amount,
            };
        }

        const blockhash = try self.sol_client.getLatestBlockhash();
        var sig_str: []const u8 = undefined;
        
        if (std.mem.eql(u8, request.asset.symbol, "SOL")) {
            var transfers = std.ArrayListUnmanaged(tx_mod.Transfer).empty;
            defer transfers.deinit(self.allocator);
            try transfers.append(self.allocator, .{ .to = request.recipient.sol, .lamports = request.amount });
            const fac_pk = if (self.facilitator) |f| try crypto.stringToPubkey(self.allocator, f) else null;
            const tx_bytes = try tx_mod.buildMultiTransferTx(self.allocator, v.sol_kp.public, transfers.items, blockhash, 1000, fac_pk);
            defer self.allocator.free(tx_bytes);
            const signature = crypto.sign(tx_bytes[65..], &v.sol_kp);
            @memcpy(tx_bytes[1..65], &signature);
            sig_str = try self.sol_client.sendTransaction(tx_bytes);
        } else {
            // SPL Token Transfer (USDT, etc)
            const mint_addr = request.asset.address orelse return error.MissingTokenAddress;
            const tx_bytes = try tx_mod.buildSplTransferTx(self.allocator, v.sol_kp.public, mint_addr, v.sol_kp.public, request.recipient.sol, request.amount, blockhash);
            defer self.allocator.free(tx_bytes);
            const signature = crypto.sign(tx_bytes[65..], &v.sol_kp);
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

        const addr_str = try evm_mod.addressToHex(self.allocator, request.recipient.evm);
        defer self.allocator.free(addr_str);

        if (!self.constitution.isActionAllowed(addr_str)) return error.ConstitutionalViolation;
        if (!try v.canSpend(total_amount, request.asset, addr_str)) return error.PolicyViolation;

        const nonce = try self.evm_client.getNonce(eth_kp.address);
        const gas_price = try self.evm_client.getGasPrice();

        const tx = tx_mod.EthEip1559Tx{
            .chain_id = 84532,
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
        
        try v.recordSpend(total_amount, request.asset);
        const tx_hash_hex = try crypto.bytesToHex(self.allocator, &tx_hash);
        defer self.allocator.free(tx_hash_hex);

        return PaymentResult{
            .tx_signature = try std.fmt.allocPrint(self.allocator, "0x{s}", .{tx_hash_hex}),
            .chain = request.asset.chain,
            .strategy = strategy,
            .fee_paid = (21000 * gas_price) + tax_amount,
        };
    }

    pub fn asAppRouter(self: *PaymentRouter) @import("../kernel/app.zig").IAppRouter {
        return .{
            .ptr = self,
            .lockFundsFn = struct {
                fn lock(ptr: *anyopaque, hire_id: [32]u8, amount: u64, asset: types.Asset) ![]const u8 {
                    const self_ptr: *PaymentRouter = @ptrCast(@alignCast(ptr));
                    
                    std.debug.print("\n[ROUTER]  Locking funds for App Hire {x}...", .{hire_id[0..4].*});
                    
                    if (asset.chain != .solana) return error.UnsupportedEscrowChain;

                    const v = &self_ptr.vaults.ops;
                    const blockhash = try self_ptr.sol_client.getLatestBlockhash();
                    
                    // En xB77, el bloqueo de fondos para un "Hire" se hace vía una transferencia
                    // al Escrow del programa core o directamente al merchant con un flag de escrow.
                    // Para el demo, usamos una transferencia directa con Memo que el programa core intercepta.
                    
                    var transfers = std.ArrayListUnmanaged(tx_mod.Transfer).empty;
                    defer transfers.deinit(self_ptr.allocator);
                    
                    // En un entorno productivo, el hire_id se usaría para derivar una PDA de Escrow.
                    // Aquí simplificamos usando la cuenta del merchant pero bajo control del programa.
                    try transfers.append(self_ptr.allocator, .{ 
                        .to = self_ptr.vaults.ops.sol_kp.public, // Mock: debería ser la PDA del Escrow
                        .lamports = amount 
                    });

                    const fac_pk = if (self_ptr.facilitator) |f| try crypto.stringToPubkey(self_ptr.allocator, f) else null;
                    const tx_bytes = try tx_mod.buildMultiTransferTx(self_ptr.allocator, v.sol_kp.public, transfers.items, blockhash, 1000, fac_pk);
                    defer self_ptr.allocator.free(tx_bytes);
                    
                    const signature = crypto.sign(tx_bytes[65..], &v.sol_kp);
                    @memcpy(tx_bytes[1..65], &signature);
                    
                    return try self_ptr.sol_client.sendTransaction(tx_bytes);
                }
            }.lock,
        };
    }
};
