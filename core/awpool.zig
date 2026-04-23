const std = @import("std");
const core = @import("core.zig");
const awp = @import("awp.zig");

/// AWPool: El motor de matching binario de xB77.
/// Permite el cruce de órdenes entre Agentes Soberanos vía AWP.
pub const AWPool = struct {
    allocator: std.mem.Allocator,
    buy_orders: std.ArrayListUnmanaged(awp.OrderMsg),
    sell_orders: std.ArrayListUnmanaged(awp.OrderMsg),

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

    /// Procesa una nueva orden y busca un match inmediato (Dark Pool style)
    pub fn processOrder(self: *AWPool, order: awp.OrderMsg) !void {
        std.debug.print("[AWPool] 🌊 New Order: {s} {s} {d} @ {d}\n", .{
            @tagName(order.side),
            order.asset.symbol,
            order.amount,
            order.price
        });

        // Lógica de Matching simplificada para S8
        var matched = false;
        if (order.side == .buy) {
            for (self.sell_orders.items, 0..) |*sell, i| {
                if (std.mem.eql(u8, sell.asset.symbol, order.asset.symbol) and sell.price <= order.price) {
                    std.debug.print("[AWPool] 🎯 MATCH FOUND! Crossing sovereign liquidity.\n", .{});
                    _ = self.sell_orders.orderedRemove(i);
                    matched = true;
                    break;
                }
            }
            if (!matched) try self.buy_orders.append(self.allocator, order);
        } else {
            for (self.buy_orders.items, 0..) |*buy, i| {
                if (std.mem.eql(u8, buy.asset.symbol, order.asset.symbol) and buy.price >= order.price) {
                    std.debug.print("[AWPool] 🎯 MATCH FOUND! Crossing sovereign liquidity.\n", .{});
                    _ = self.buy_orders.orderedRemove(i);
                    matched = true;
                    break;
                }
            }
            if (!matched) try self.sell_orders.append(self.allocator, order);
        }
    }
};
