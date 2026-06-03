const std = @import("std");
const core = @import("core");
const awp = core.awp;

/// xB77 Sovereign SDK - Zig Implementation
/// Este archivo se puede compilar como una librería estática o compartida
/// para ser usada por cualquier lenguaje (TS, Python, C++, etc).

pub const Client = struct {
    allocator: std.mem.Allocator,
    socket_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, socket_path: []const u8) Client {
        return .{
            .allocator = allocator,
            .socket_path = socket_path,
        };
    }

    pub fn submitOrder(self: *Client, msg: awp.OrderMsg) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        const ua = try std.Io.net.UnixAddress.init(self.socket_path);
        var stream = try ua.connect(io);
        defer stream.close(io);

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const bytes = try encoder.encodeOrder(msg);
        var write_buffer: [1024]u8 = undefined;
        var writer = stream.writer(io, &write_buffer);
        try writer.interface.writeAll(bytes);
    }
};

// --- C ABI EXPORTS ---
// Esto permite que el resto del mundo use el SDK nativo de xB77.

export fn xb77_submit_order_c(
    side: u8, 
    chain: u8, 
    symbol: [*]const u8, 
    symbol_len: usize,
    amount: u64, 
    price: u64
) bool {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    var client = Client.init(allocator, "/tmp/xb77_znode.sock");
    
    const order = awp.OrderMsg{
        .side = @enumFromInt(side),
        .asset = .{ 
            .chain = @enumFromInt(chain), 
            .symbol = symbol[0..symbol_len] 
        },
        .amount = amount,
        .price = price,
        .nonce = 12345, // Simulado para el C-export
        .owner = [_]u8{0} ** 32,
    };

    client.submitOrder(order) catch return false;
    return true;
}
