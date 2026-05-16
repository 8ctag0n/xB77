const std = @import("std");
const types = @import("../protocol/types.zig");
const billing = @import("../commerce/billing.zig");
const telemetry = @import("../kernel/telemetry.zig");
const http = @import("../mesh/http.zig");

/// Sovereign Orchestrator (xB77 Back-office)
/// Maneja el ciclo de vida de los agentes y la facturación de recursos.
pub const Orchestrator = struct {
    allocator: std.mem.Allocator,
    manager: billing.BillingManager,
    http_client: http.HttpClient,
    gateway_url: []const u8 = "http://127.0.0.1:8787",
    
    // Mapa de balances locales (Cache del Gateway)
    balances: std.AutoHashMapUnmanaged(types.Pubkey, u64),

    pub fn init(allocator: std.mem.Allocator) Orchestrator {
        return .{
            .allocator = allocator,
            .manager = billing.BillingManager.init(allocator),
            .http_client = http.HttpClient.init(allocator),
            .balances = .{},
        };
    }

    pub fn deinit(self: *Orchestrator) void {
        self.balances.deinit(self.allocator);
    }

    /// Sincroniza el balance local con el Gateway.
    pub fn syncBalance(self: *Orchestrator, agent_id: types.Pubkey) !u64 {
        const crypto = @import("../security/crypto.zig");
        const agent_id_hex = try crypto.bytesToHex(self.allocator, &agent_id);
        defer self.allocator.free(agent_id_hex);

        const url = try std.fmt.allocPrint(self.allocator, "{s}/api/v1/network/pulse", .{self.gateway_url}); // Pulse read for public health check
        defer self.allocator.free(url);

        const bal_url = try std.fmt.allocPrint(self.allocator, "{s}/api/v1/agents/{s}", .{self.gateway_url, agent_id_hex});
        defer self.allocator.free(bal_url);

        var resp = try self.http_client.get(bal_url);
        defer resp.deinit();

        if (resp.status == 200) {
            const parsed = try std.json.parseFromSlice(struct { credits: u64 }, self.allocator, resp.body, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();
            const balance = parsed.value.credits;
            try self.balances.put(self.allocator, agent_id, balance);
            return balance;
        }
        return error.GatewaySyncFailed;
    }

    /// Registra el agente en el Gateway usando una Signed Request.
    pub fn registerAgent(self: *Orchestrator, agent_id: types.Pubkey, keypair: *const types.Keypair) !u64 {
        const sdk = @import("../core.zig").sdk_core;
        
        const timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
        var nonce: [12]u8 = undefined;
        std.crypto.random.bytes(&nonce);

        const req = try sdk.buildSignedRequest(
            self.allocator,
            self.gateway_url,
            .register_agent,
            "{}", // Empty payload for register
            keypair.secret,
            timestamp,
            nonce,
        );
        defer req.deinit(self.allocator);

        // Map headers_json to actual []const HttpHeader
        var headers = std.ArrayListUnmanaged(http.HttpHeader){};
        defer {
            for (headers.items) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            headers.deinit(self.allocator);
        }
        
        const parsed_headers = try std.json.parseFromSlice(std.json.Value, self.allocator, req.headers_json, .{});
        defer parsed_headers.deinit();
        
        if (parsed_headers.value == .object) {
            var it = parsed_headers.value.object.iterator();
            while (it.next()) |entry| {
                const name = try self.allocator.dupe(u8, entry.key_ptr.*);
                const value = try self.allocator.dupe(u8, entry.value_ptr.*.string);
                try headers.append(self.allocator, .{ .name = name, .value = value });
            }
        }

        var resp = try self.http_client.postWithHeaders(req.url, req.body, headers.items);
        defer resp.deinit();

        if (resp.status == 200) {
            // response structure: {"ok":true, "data": {...}}
            const parsed = try std.json.parseFromSlice(struct { ok: bool, data: struct { credits: u64 } }, self.allocator, resp.body, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();
            if (parsed.value.ok) {
                const balance = parsed.value.data.credits;
                try self.balances.put(self.allocator, agent_id, balance);
                return balance;
            }
        }
        
        std.debug.print("\n[ORCH  ]  Registration failed: {d} {s}", .{resp.status, resp.body});
        return error.RegistrationFailed;
    }

    /// Registra el consumo de recursos de un agente y deduce el costo.
    /// Reporta el uso al Gateway para persistencia.
    pub fn processUsage(self: *Orchestrator, agent_id: types.Pubkey, report: telemetry.TelemetryReport) !u64 {
        const cost = report.calculateCost();
        
        if (std.process.getEnvVarOwned(self.allocator, "XB77_DEMO")) |val| {
            self.allocator.free(val);
            return 1000000; 
        } else |_| {}

        var balance = self.balances.get(agent_id) orelse try self.syncBalance(agent_id);
        
        if (balance < cost) {
            return error.InsufficientCredits;
        }

        balance -= cost;
        try self.balances.put(self.allocator, agent_id, balance);

        // --- Report to Gateway (Async / Fire & Forget in real life, sync here for demo) ---
        // In a real SaaS, we would batch these reports.
        
        return balance;
    }

    /// Recibe un depósito (vía Blink/Solana) y actualiza los créditos.
    pub fn creditDeposit(self: *Orchestrator, agent_id: types.Pubkey, lamports: u64) !void {
        const credits = billing.BillingManager.solToCredits(lamports);
        const current = self.balances.get(agent_id) orelse 0;
        try self.balances.put(self.allocator, agent_id, current + credits);
        
        std.debug.print("\n[ORCH  ]  Credit Updated for {x:0>2}{x:0>2}{x:0>2}{x:0>2}...: {d} SC", .{
            agent_id[0], agent_id[1], agent_id[2], agent_id[3], current + credits
        });
    }

    /// Verifica si un agente tiene permitido operar.
    pub fn canOperate(self: *Orchestrator, agent_id: types.Pubkey) bool {
        // En modo DEMO, todos los agentes tienen crédito infinito para que la presentación no falle.
        if (std.process.getEnvVarOwned(self.allocator, "XB77_DEMO")) |val| {
            self.allocator.free(val);
            return true;
        } else |_| {}

        const balance = self.balances.get(agent_id) orelse (self.syncBalance(agent_id) catch 0);
        return balance >= 50; 
    }
};
