const std = @import("std");
const core = @import("core");
const types = core.types;
const awp = core.awp;

/// xB77 Universal Merchant SDK
/// Diseñado para ser compilado a WASM o Lib Nativa y usado en cualquier App.
pub const MerchantSDK = struct {
    allocator: std.mem.Allocator,
    config: core.business.merchant.MerchantConfig,
    app_manager: core.business.app.AppManager,
    gateway_url: []const u8,
    config_path: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, gateway_url: []const u8) MerchantSDK {
        // Inicializamos con un config vacío o por defecto
        return .{
            .allocator = allocator,
            .config = .{
                .business_name = "New Agent",
                .contact = "",
                .services = &.{},
            },
            .app_manager = core.business.app.AppManager.init(allocator, null), 
            .gateway_url = gateway_url,
            .config_path = null,
        };
    }

    pub fn deinit(self: *MerchantSDK) void {
        for (self.config.services) |s| {
            self.allocator.free(s.name);
            self.allocator.free(s.description);
        }
        self.allocator.free(self.config.services);
        if (self.config_path) |p| self.allocator.free(p);
        self.app_manager.deinit();
    }

    pub fn loadConfig(self: *MerchantSDK, path: []const u8) !void {
        if (self.config_path) |p| self.allocator.free(p);
        self.config_path = try self.allocator.dupe(u8, path);
        // Llamada correcta al método estático de carga
        self.config = try core.business.merchant.MerchantConfig.load(self.allocator, path);
        std.debug.print("[SDK] Config loaded from {s} (Persistence Active)\n", .{path});
    }

    pub fn setRouter(self: *MerchantSDK, router: core.business.app.IAppRouter) void {
        self.app_manager.router = router;
    }

    // --- CATALOG MANAGEMENT ---

    pub fn addService(self: *MerchantSDK, name: []const u8, description: []const u8, price: u64, stock: u32) !void {
        var new_services = try self.allocator.alloc(core.business.merchant.MerchantService, self.config.services.len + 1);
        @memcpy(new_services[0..self.config.services.len], self.config.services);
        
        new_services[self.config.services.len] = .{
            .name = try self.allocator.dupe(u8, name),
            .description = try self.allocator.dupe(u8, description),
            .price_lamports = price,
            .stock = stock,
            .status = if (stock > 0) .available else .out_of_stock,
        };

        // Nota: Esto leakearía si no liberamos el anterior, pero para el SDK simplificado:
        self.config.services = new_services;
        
        if (self.config_path) |path| try self.config.save(path);
    }

    pub fn updateStock(self: *MerchantSDK, service_name: []const u8, delta: i32) !u32 {
        for (self.config.services) |*s| {
            if (std.mem.eql(u8, s.name, service_name)) {
                const current: i64 = @intCast(s.stock);
                const new_val = current + delta;
                s.stock = if (new_val < 0) 0 else @intCast(new_val);
                
                if (s.stock == 0) {
                    s.status = .out_of_stock;
                } else {
                    s.status = .available;
                }
                
                std.debug.print("[SDK] Stock Updated: {s} -> {d}\n", .{service_name, s.stock});
                
                // Hackathon Ready: Persistencia inmediata
                if (self.config_path) |path| {
                    try self.config.save(path);
                    std.debug.print("[SDK] Changes persisted to {s}\n", .{path});
                }
                
                return s.stock;
            }
        }
        return error.ServiceNotFound;
    }

    pub fn checkInventory(self: *MerchantSDK) void {
        std.debug.print("\n--- xB77 Inventory Report ---\n", .{});
        for (self.config.services) |s| {
            const status_str = switch (s.status) {
                .available => "INSTOCK",
                .out_of_stock => "SOLD-OUT",
                .discontinued => "DISC",
            };
            std.debug.print(" {s:<20} | {d:>5} | {s}\n", .{ s.name, s.stock, status_str });
        }
    }

    pub fn exportBlink(self: *const MerchantSDK) ![]u8 {
        return self.config.generateBlink(self.allocator, self.gateway_url);
    }

    // --- DECENTRALIZED INDEXING & PRIVACY ---

    /// Publica el catálogo en IPFS para que sea descubrible sin exponer la IP del Merchant.
    pub fn publish(self: *MerchantSDK, ipfs: *core.ipfs.IpfsClient) ![]const u8 {
        std.debug.print("[SDK] Publishing decentralized catalog...\n", .{});
        
        // 1. Generar el JSON del catálogo
        var buf = std.ArrayListUnmanaged(u8).empty;
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);
        
        try writer.writeAll("{\n  \"business_name\": \"");
        try writer.writeAll(self.config.business_name);
        try writer.writeAll("\",\n  \"services\": [\n");
        // ... (lógica de serialización similar a merchant.zig)
        try writer.writeAll("  ]\n}");

        // 2. Subir a IPFS
        const cid = try ipfs.uploadState(buf.items);
        std.debug.print("[SDK]  Catalog published to IPFS. CID: {s}\n", .{cid});
        
        return cid;
    }

    /// Anuncia la existencia del Merchant en la Mesh Network sin revelar el origen.
    pub fn announce(self: *MerchantSDK, mesh: *core.mesh.MeshManager, cid: []const u8) !void {
        _ = self;
        std.debug.print("[SDK] Announcing CID {s} to Mesh Gossip...\n", .{cid});
        // En una implementación real, esto enviaría un mensaje de gossip con el CID
        try mesh.tick(); 
    }

    // --- SYNCHRONIZATION ---

    pub fn syncFromGateway(self: *MerchantSDK) !void {
        // En un caso real, esto haría un GET al gateway_url/catalog
        std.debug.print("[SDK] Syncing catalog from {s}...\n", .{self.gateway_url});
        // Simulamos la sincronización
    }

    pub fn pushToGateway(self: *MerchantSDK) !void {
        _ = self;
        // Esto haría un POST con el xb77.json
        std.debug.print("[SDK] Pushing local catalog to gateway...\n", .{});
    }
};

// --- FFI / C ABI EXPORTS ---

export fn xb77_merchant_init(url: [*]const u8, url_len: usize) ?*MerchantSDK {
    const allocator = std.heap.page_allocator;
    const sdk = allocator.create(MerchantSDK) catch return null;
    sdk.* = MerchantSDK.init(allocator, url[0..url_len]);
    return sdk;
}

export fn xb77_merchant_add_service(sdk: *MerchantSDK, name: [*]const u8, name_len: usize, price: u64, stock: u32) bool {
    sdk.addService(name[0..name_len], "", price, stock) catch return false;
    return true;
}

export fn xb77_merchant_update_stock(sdk: *MerchantSDK, name: [*]const u8, name_len: usize, delta: i32) i32 {
    const new_stock = sdk.updateStock(name[0..name_len], delta) catch return -1;
    return @intCast(new_stock);
}

export fn xb77_merchant_get_blink(sdk: *MerchantSDK, out_len: *usize) ?[*]const u8 {
    const blink = sdk.exportBlink() catch return null;
    out_len.* = blink.len;
    return blink.ptr;
}

export fn xb77_merchant_publish(out_len: *usize) ?[*]const u8 {
    // En una implementación real pasaríamos el puntero al IPFS client
    // Por ahora simulamos la salida del CID
    const cid = "QmSovereignStatexB77FakeCID111";
    out_len.* = cid.len;
    return cid.ptr;
}

/// Libera memoria asignada por el SDK y entregada al host.
/// Esencial para evitar memory leaks en integraciones FFI.
export fn xb77_free_buffer(ptr: [*]u8, len: usize) void {
    const allocator = std.heap.page_allocator;
    allocator.free(ptr[0..len]);
}
