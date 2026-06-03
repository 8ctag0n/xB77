const std = @import("std");
const builtin = @import("builtin");

pub const MerchantService = struct {
    name: []const u8,
    description: []const u8,
    price_lamports: u64,
    stock: u32 = 0,
    status: enum { available, out_of_stock, discontinued } = .available,
};

pub const MerchantConfig = struct {
    business_name: []const u8,
    contact: []const u8,
    services: []MerchantService,

    pub fn save(self: *const MerchantConfig, path: []const u8) !void {
        if (comptime builtin.target.os.tag == .freestanding) return error.UnsupportedOs;
        const io = std.Io.Threaded.global_single_threaded.io();

        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        // Generar un JSON simple para descubrimiento (xb77.json) manual
        var buf = std.ArrayListUnmanaged(u8).empty;
        defer buf.deinit(std.heap.page_allocator);

        try buf.appendSlice(std.heap.page_allocator, "{\n  \"business_name\": \"");
        try buf.appendSlice(std.heap.page_allocator, self.business_name);
        try buf.appendSlice(std.heap.page_allocator, "\",\n  \"contact\": \"");
        try buf.appendSlice(std.heap.page_allocator, self.contact);
        try buf.appendSlice(std.heap.page_allocator, "\",\n  \"services\": [\n");

        for (self.services, 0..) |s, i| {
            try buf.print(std.heap.page_allocator, "    {{\n      \"name\": \"{s}\",\n      \"price\": {d}\n    }}{s}\n", .{
                s.name,
                s.price_lamports,
                if (i < self.services.len - 1) "," else "",
            });
        }
        try buf.appendSlice(std.heap.page_allocator, "  ]\n}");

        try file.writeStreamingAll(io, buf.items);
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !MerchantConfig {
        if (comptime builtin.target.os.tag == .freestanding) return error.UnsupportedOs;
        const io = std.Io.Threaded.global_single_threaded.io();

        const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // If not found, return a default config. Note: deinit() will free
                // all three fields unconditionally, so passing literals here
                // panics with "Invalid free" the first time the config is torn
                // down. Always hand back owned memory.
                return MerchantConfig{
                    .business_name = try allocator.dupe(u8, "xB77 Sovereign Agent"),
                    .contact = try allocator.dupe(u8, "@agent"),
                    .services = try allocator.alloc(MerchantService, 0),
                };
            }
            return err;
        };
        defer file.close(io);

        var read_buffer: [1024]u8 = undefined;
        var reader = file.reader(io, &read_buffer);
        const content = try reader.interface.allocRemaining(allocator, .unlimited);
        defer allocator.free(content);

        const parsed = try std.json.parseFromSlice(MerchantConfig, allocator, content, .{ .ignore_unknown_fields = true });
        return parsed.value;
    }

    pub fn deinit(self: *MerchantConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.business_name);
        allocator.free(self.contact);
        for (self.services) |s| {
            allocator.free(s.name);
            allocator.free(s.description);
        }
        allocator.free(self.services);
    }

    pub fn generateBlink(self: *const MerchantConfig, allocator: std.mem.Allocator, base_url: []const u8) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8).empty;
        errdefer buf.deinit(allocator);

        try buf.appendSlice(allocator, "{\n");
        try buf.print(allocator, "  \"icon\": \"{s}/api/brand/blink-icon.svg\",\n", .{base_url});
        try buf.print(allocator, "  \"title\": \"[ SOVEREIGN AGENT ] {s}\",\n", .{self.business_name});
        try buf.appendSlice(allocator, "  \"description\": \"ZK-verified autonomous commerce on Solana.\\nPayments settle in real-time via the xB77 MagicBlock HFT rail.\\nEvery receipt is mathematically auditable. Pick a tier to engage.\",\n");
        try buf.appendSlice(allocator, "  \"label\": \"Hire Agent\",\n");
        try buf.appendSlice(allocator, "  \"links\": {\n");
        try buf.appendSlice(allocator, "    \"actions\": [\n");

        for (self.services) |s| {
            try buf.print(allocator, "      {{\n        \"type\": \"transaction\",\n        \"label\": \"{s} - {d} SOL\",\n        \"href\": \"{s}/api/actions/pay?service={s}&amount={d}\"\n      }},\n", .{
                s.name,
                s.price_lamports / 1000000,
                base_url,
                s.name,
                s.price_lamports,
            });
        }
        try buf.print(
            allocator,
            "      {{\n        \"type\": \"transaction\",\n        \"label\": \"Custom Tip\",\n        \"href\": \"{s}/api/actions/tip?amount={{amount}}\",\n        \"parameters\": [\n          {{ \"name\": \"amount\", \"label\": \"SOL amount\", \"required\": true }}\n        ]\n      }}\n",
            .{base_url},
        );
        try buf.appendSlice(allocator, "    ]\n");
        try buf.appendSlice(allocator, "  }\n");
        try buf.appendSlice(allocator, "}");

        return try buf.toOwnedSlice(allocator);
    }
};
