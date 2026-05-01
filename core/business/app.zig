const std = @import("std");
const core = @import("../core.zig");
const types = @import("../protocol/types.zig");
const awp = @import("../protocol/awp.zig");
const crypto = @import("../crypto/crypto.zig");

/// Interface para el Router de Pagos (permite desacoplar el AppManager del contexto completo)
pub const IAppRouter = struct {
    ptr: *anyopaque,
    lockFundsFn: *const fn (ptr: *anyopaque, hire_id: [32]u8, amount: u64, asset: types.Asset) anyerror![]const u8,

    pub fn lockFunds(self: IAppRouter, hire_id: [32]u8, amount: u64, asset: types.Asset) ![]const u8 {
        return self.lockFundsFn(self.ptr, hire_id, amount, asset);
    }
};

/// Agent Payments Protocol (APP) Manager
/// Orquestra el flujo de Quotes, Hires y Escrows.
pub const AppManager = struct {
    allocator: std.mem.Allocator,
    router: ?IAppRouter,
    quotes: std.AutoHashMapUnmanaged([32]u8, awp.AppQuoteMsg),
    hires: std.AutoHashMapUnmanaged([32]u8, awp.AppHireMsg),
    disputes: std.AutoHashMapUnmanaged([32]u8, awp.AppDisputeOpenMsg),
    plans: std.AutoHashMapUnmanaged([32]u8, awp.AppPlanMsg),

    pub fn init(allocator: std.mem.Allocator, router: ?IAppRouter) AppManager {
        return .{
            .allocator = allocator,
            .router = router,
            .quotes = .{},
            .hires = .{},
            .disputes = .{},
            .plans = .{},
        };
    }

    pub fn deinit(self: *AppManager) void {
        self.quotes.deinit(self.allocator);
        self.hires.deinit(self.allocator);
        self.disputes.deinit(self.allocator);
        self.plans.deinit(self.allocator);
    }

    /// Genera un nuevo presupuesto para un servicio.
    pub fn createQuote(self: *AppManager, asset: types.Asset, price: u64, expiry_sec: u64) !awp.AppQuoteMsg {
        var quote_id: [32]u8 = undefined;
        std.crypto.random.bytes(&quote_id);

        const quote = awp.AppQuoteMsg{
            .quote_id = quote_id,
            .asset = awp.toAwpAsset(asset),
            .price = price,
            .expiry = @intCast(std.time.timestamp() + @as(i64, @intCast(expiry_sec))),
        };

        try self.quotes.put(self.allocator, quote_id, quote);
        std.debug.print("[APP] Quote Generated | Price: {d} {s}\n", .{
            price, asset.symbol
        });
        
        return quote;
    }

    /// Procesa una solicitud de contratación (Hire) entrante.
    /// Valida el presupuesto y bloquea los fondos si es el cliente, 
    /// o registra el contrato si es el proveedor.
    pub fn handleHire(self: *AppManager, msg: awp.AppHireMsg) !void {
        const quote = self.quotes.get(msg.quote_id) orelse return error.QuoteNotFound;
        
        if (std.time.timestamp() > quote.expiry) return error.QuoteExpired;
        if (msg.escrow_amount < quote.price) return error.InsufficientEscrow;

        try self.hires.put(self.allocator, msg.hire_id, msg);
        
        std.debug.print("[APP] Hire Confirmed for Quote\n", .{});
    }

    /// Lógica de Cliente: Inicia el bloqueo de fondos tras recibir una Quote.
    pub fn acceptQuote(self: *AppManager, quote: awp.AppQuoteMsg) ![]const u8 {
        var hire_id: [32]u8 = undefined;
        std.crypto.random.bytes(&hire_id);

        const asset = types.Asset{
            .chain = awp.fromAwpChain(quote.asset.chain),
            .symbol = quote.asset.symbol,
        };

        // 1. Bloquear fondos en el Escrow
        const r = self.router orelse return error.RouterNotInitialized;
        const tx_sig = try r.lockFunds(hire_id, quote.price, asset);

        // 2. Registrar Hire localmente
        const hire_msg = awp.AppHireMsg{
            .hire_id = hire_id,
            .quote_id = quote.quote_id,
            .escrow_amount = quote.price,
        };
        try self.hires.put(self.allocator, hire_id, hire_msg);

        return tx_sig;
    }

    /// Abre una disputa sobre una contratación activa.
    pub fn openDispute(self: *AppManager, hire_id: [32]u8, reason: []const u8) !awp.AppDisputeOpenMsg {
        if (!self.hires.contains(hire_id)) return error.HireNotFound;
        
        const msg = awp.AppDisputeOpenMsg{
            .hire_id = hire_id,
            .reason = try self.allocator.dupe(u8, reason),
        };
        try self.disputes.put(self.allocator, hire_id, msg);
        
        std.debug.print("[APP] Dispute Opened for Hire {x}: {s}\n", .{ hire_id[0..4].*, reason });
        return msg;
    }

    /// Resuelve una disputa (Lógica de Árbitro).
    pub fn resolveDispute(self: *AppManager, msg: awp.AppDisputeResolveMsg) !void {
        _ = self;
        // En una implementación real, verificaríamos la firma del árbitro
        // y ejecutaríamos la distribución de fondos del Escrow.
        std.debug.print("[APP] Dispute Resolved for Hire {x}. Resolution: {any}\n", .{ msg.hire_id[0..4].*, msg.resolution });
    }

    /// Crea un plan de pagos recurrentes.
    pub fn createPlan(self: *AppManager, asset: types.Asset, amount: u64, period: u64, total: u64) !awp.AppPlanMsg {
        var plan_id: [32]u8 = undefined;
        std.crypto.random.bytes(&plan_id);

        const plan = awp.AppPlanMsg{
            .plan_id = plan_id,
            .asset = awp.toAwpAsset(asset),
            .amount_per_period = amount,
            .period_sec = period,
            .total_periods = total,
        };

        try self.plans.put(self.allocator, plan_id, plan);
        std.debug.print("[APP] Recurring Plan Created: {x} | {d} {s} every {d}s\n", .{
            plan_id[0..4].*, amount, asset.symbol, period
        });
        
        return plan;
    }
};
