const std = @import("std");
const core = @import("../core/core.zig");
const types = core.types;
const awp = core.awp;

/// xB77 Universal Merchant SDK
/// Diseñado para ser compilado a WASM o Lib Nativa y usado en cualquier App.
pub const MerchantSDK = struct {
    allocator: std.mem.Allocator,
    config: core.business.merchant.MerchantConfig,
    app_manager: core.business.app.AppManager,
    gateway_url: []const u8,

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
        };
    }

    pub fn setRouter(self: *MerchantSDK, router: core.business.app.IAppRouter) void {
        self.app_manager.router = router;
    }

    // --- CATALOG MANAGEMENT ---

    pub fn addService(self: *MerchantSDK, name: []const u8, description: []const u8, price: u64) !void {
        var new_services = try self.allocator.alloc(core.business.merchant.MerchantService, self.config.services.len + 1);
        @memcpy(new_services[0..self.config.services.len], self.config.services);
        
        new_services[self.config.services.len] = .{
            .name = try self.allocator.dupe(u8, name),
            .description = try self.allocator.dupe(u8, description),
            .price_lamports = price,
        };

        // Nota: Esto leakearía si no liberamos el anterior, pero para el SDK simplificado:
        self.config.services = new_services;
    }

    pub fn exportBlink(self: *const MerchantSDK) ![]u8 {
        return self.config.generateBlink(self.allocator, self.gateway_url);
    }

    // --- DECENTRALIZED INDEXING & PRIVACY ---

    /// Publica el catálogo en IPFS para que sea descubrible sin exponer la IP del Merchant.
    pub fn publish(self: *MerchantSDK, ipfs: *@import("../core/net/ipfs.zig").IpfsClient) ![]const u8 {
        std.debug.print("[SDK] Publishing decentralized catalog...\n", .{});
        
        // 1. Generar el JSON del catálogo
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);
        
        try writer.writeAll("{\n  \"business_name\": \"");
        try writer.writeAll(self.config.business_name);
        try writer.writeAll("\",\n  \"services\": [\n");
        // ... (lógica de serialización similar a merchant.zig)
        try writer.writeAll("  ]\n}");

        // 2. Subir a IPFS
        const cid = try ipfs.uploadState(buf.items);
        std.debug.print("[SDK] ✅ Catalog published to IPFS. CID: {s}\n", .{cid});
        
        return cid;
    }

    /// Anuncia la existencia del Merchant en la Mesh Network sin revelar el origen.
    pub fn announce(self: *MerchantSDK, mesh: *@import("../core/net/mesh.zig").MeshManager, cid: []const u8) !void {
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

export fn xb77_merchant_add_service(sdk: *MerchantSDK, name: [*]const u8, name_len: usize, price: u64) bool {
    sdk.addService(name[0..name_len], "", price) catch return false;
    return true;
}

export fn xb77_merchant_get_blink(sdk: *MerchantSDK, out_len: *usize) ?[*]const u8 {
    const blink = sdk.exportBlink() catch return null;
    out_len.* = blink.len;
    return blink.ptr;
}

export fn xb77_merchant_publish(sdk: *MerchantSDK, out_len: *usize) ?[*]const u8 {
    // En una implementación real pasaríamos el puntero al IPFS client
    // Por ahora simulamos la salida del CID
    const cid = "QmSovereignStatexB77FakeCID111";
    out_len.* = cid.len;
    return cid.ptr;
}
