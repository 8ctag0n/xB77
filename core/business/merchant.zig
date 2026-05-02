const std = @import("std");

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
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Generar un JSON simple para descubrimiento (xb77.json) manual
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(std.heap.page_allocator);
        const writer = buf.writer(std.heap.page_allocator);

        try writer.writeAll("{\n  \"business_name\": \"");
        try writer.writeAll(self.business_name);
        try writer.writeAll("\",\n  \"contact\": \"");
        try writer.writeAll(self.contact);
        try writer.writeAll("\",\n  \"services\": [\n");

        for (self.services, 0..) |s, i| {
            try writer.print("    {{\n      \"name\": \"{s}\",\n      \"price\": {d}\n    }}{s}\n", .{
                s.name,
                s.price_lamports,
                if (i < self.services.len - 1) "," else "",
            });
        }
        try writer.writeAll("  ]\n}");

        try file.writeAll(buf.items);
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !MerchantConfig {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return MerchantConfig{
                    .business_name = "xB77 Sovereign Agent",
                    .contact = "@agent",
                    .services = &.{},
                };
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const obj = parsed.value.object;
        const b_name = try allocator.dupe(u8, obj.get("business_name").?.string);
        const contact = try allocator.dupe(u8, obj.get("contact").?.string);

        const services_json = obj.get("services").?.array;
        var services = try allocator.alloc(MerchantService, services_json.items.len);

        for (services_json.items, 0..) |s_val, i| {
            const s_obj = s_val.object;
            services[i] = .{
                .name = try allocator.dupe(u8, s_obj.get("name").?.string),
                .description = "Imported Service",
                .price_lamports = @intCast(s_obj.get("price").?.integer),
                .stock = if (s_obj.get("stock")) |v| @intCast(v.integer) else 10,
                .status = .available,
            };
        }

        return MerchantConfig{
            .business_name = b_name,
            .contact = contact,
            .services = services,
        };
    }

    pub fn generateBlink(self: *const MerchantConfig, allocator: std.mem.Allocator, base_url: []const u8) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        try writer.writeAll("{\n");
        try writer.writeAll("  \"icon\": \"https://xb77.app/logo.png\",\n");
        try writer.print("  \"title\": \"{s}\",\n", .{self.business_name});
        try writer.writeAll("  \"description\": \"Sovereign Agent Service - Machine Verified\",\n");
        try writer.writeAll("  \"label\": \"Purchase\",\n");
        try writer.writeAll("  \"links\": {\n");
        try writer.writeAll("    \"actions\": [\n");

        for (self.services, 0..) |s, i| {
            try writer.print("      {{\n        \"label\": \"{s}\",\n        \"href\": \"{s}/api/actions/pay?service={s}&amount={d}\"\n      }}{s}\n", .{
                s.name,
                base_url,
                s.name,
                s.price_lamports,
                if (i < self.services.len - 1) "," else "",
            });
        }

        try writer.writeAll("    ]\n");
        try writer.writeAll("  }\n");
        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};
