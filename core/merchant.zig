const std = @import("std");

pub const MerchantService = struct {
    name: []const u8,
    description: []const u8,
    price_lamports: u64,
};

pub const MerchantConfig = struct {
    business_name: []const u8,
    contact: []const u8,
    services: []const MerchantService,

    pub fn save(self: *const MerchantConfig, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Generar un JSON simple para descubrimiento (xb77.json)
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();

        var list = std.json.Value.initObject(allocator);
        try list.object.put("business_name", std.json.Value{ .string = self.business_name });
        try list.object.put("contact", std.json.Value{ .string = self.contact });

        var services_arr = std.json.Value.initArray(allocator);
        for (self.services) |s| {
            var s_obj = std.json.Value.initObject(allocator);
            try s_obj.object.put("name", std.json.Value{ .string = s.name });
            try s_obj.object.put("price", std.json.Value{ .integer = @intCast(s.price_lamports) });
            try services_arr.array.append(s_obj);
        }
        try list.object.put("services", services_arr);

        const json_str = try std.json.stringifyAlloc(allocator, list, .{ .whitespace = .indent_2 });
        try file.writeAll(json_str);
    }
};
