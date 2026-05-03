const std = @import("std");
const core = @import("../core.zig");
const awp = @import("../protocol/awp.zig");

const pay = @import("../business/pay.zig");
const store_mod = @import("../state/store.zig");

/// AWPool: El motor de matching binario de xB77.
/// Permite el cruce de órdenes entre Agentes Soberanos vía AWP.
pub const AWPool = struct {
    allocator: std.mem.Allocator,
    buy_orders: std.ArrayListUnmanaged(awp.OrderMsg),
    sell_orders: std.ArrayListUnmanaged(awp.OrderMsg),
    router: ?*pay.PaymentRouter = null,
    store: ?*store_mod.Store = null,

    pub fn init(allocator: std.mem.Allocator) AWPool {
        return .{
            .allocator = allocator,
            .buy_orders = .{},
            .sell_orders = .{},
        };
    }

    pub fn deinit(self: *AWPool) void {
        self.buy_orders.deinit(self.allocator);
        self.sell_orders.deinit(self.allocator);
    }

    /// Procesa una nueva orden y busca matches exhaustivamente (Waterfall style)
    pub fn processOrder(self: *AWPool, order_in: awp.OrderMsg) !void {
        var remaining_amount = order_in.amount;
        
        std.debug.print("[AWPool]  New Order: {s} {d} {s} @ {d}\n", .{
            @tagName(order_in.side),
            remaining_amount,
            order_in.asset.symbol,
            order_in.price
        });

        if (order_in.side == .buy) {
            var i: usize = 0;
            while (i < self.sell_orders.items.len and remaining_amount > 0) {
                var sell = &self.sell_orders.items[i];
                
                // ¿El precio coincide? (Sell price <= Buy price)
                if (std.mem.eql(u8, sell.asset.symbol, order_in.asset.symbol) and sell.price <= order_in.price) {
                    const match_amount = @min(remaining_amount, sell.amount);
                    
                    std.debug.print("[AWPool]  MATCH! Partial/Full fill: {d} {s}\n", .{ match_amount, sell.asset.symbol });
                    
                    try self.settle(order_in, sell.*, match_amount);
                    
                    remaining_amount -= match_amount;
                    sell.amount -= match_amount;

                    // Si la orden de venta se agotó, la quitamos del pool
                    if (sell.amount == 0) {
                        _ = self.sell_orders.orderedRemove(i);
                        // No incrementamos 'i' porque el siguiente elemento ahora está en la posición 'i'
                        continue; 
                    }
                }
                i += 1;
            }
            
            // Si después de recorrer todo, sobra cantidad, se queda en el pool
            if (remaining_amount > 0) {
                var remaining_order = order_in;
                remaining_order.amount = remaining_amount;
                try self.buy_orders.append(self.allocator, remaining_order);
                std.debug.print("[AWPool]  Remaining {d} added to Buy Orders.\n", .{remaining_amount});
            }
        } else {
            // Lógica simétrica para SELL
            var i: usize = 0;
            while (i < self.buy_orders.items.len and remaining_amount > 0) {
                var buy = &self.buy_orders.items[i];
                
                if (std.mem.eql(u8, buy.asset.symbol, order_in.asset.symbol) and buy.price >= order_in.price) {
                    const match_amount = @min(remaining_amount, buy.amount);
                    
                    std.debug.print("[AWPool]  MATCH! Partial/Full fill: {d} {s}\n", .{ match_amount, buy.asset.symbol });
                    
                    try self.settle(buy.*, order_in, match_amount);
                    
                    remaining_amount -= match_amount;
                    buy.amount -= match_amount;

                    if (buy.amount == 0) {
                        _ = self.buy_orders.orderedRemove(i);
                        continue;
                    }
                }
                i += 1;
            }

            if (remaining_amount > 0) {
                var remaining_order = order_in;
                remaining_order.amount = remaining_amount;
                try self.sell_orders.append(self.allocator, remaining_order);
                std.debug.print("[AWPool]  Remaining {d} added to Sell Orders.\n", .{remaining_amount});
            }
        }
    }

    fn settle(self: *AWPool, buy: awp.OrderMsg, sell: awp.OrderMsg, amount: u64) !void {
        const router = self.router orelse return;

        std.debug.print("[AWPool]  Settling match: {d} {s} (Buy owner: {x}, Sell owner: {x})\n", .{ 
            amount, 
            sell.asset.symbol,
            buy.owner[0..4].*,
            sell.owner[0..4].*
        });

        //  REGISTRO REAL EN EL LEDGER PRIVADO
        if (self.store) |s| {
            s.record(.{
                .timestamp = std.time.milliTimestamp(),
                .chain = awp.fromAwpChain(sell.asset.chain),
                .entry_type = .match,
                .description = "P2P Match Settled",
                .amount = amount,
            }) catch |err| {
                std.debug.print("[AWPool] ️ Failed to record match: {}\n", .{err});
            };
        }

        _ = router; 
    }
};
