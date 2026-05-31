const std = @import("std");
const core = @import("../core.zig");
const context_mod = @import("context.zig");

/// Sovereign Telemetry Bridge: Proporciona una interfaz HTTP/JSON para el Dashboard Web.
/// Permite que la WebApp (Localhost) visualice el estado interno del agente soberano.
pub const HttpBridge = struct {
    allocator: std.mem.Allocator,
    ctx: *context_mod.AgentContext,
    port: u16 = 8080,

    pub fn init(allocator: std.mem.Allocator, ctx: *context_mod.AgentContext) HttpBridge {
        return .{
            .allocator = allocator,
            .ctx = ctx,
        };
    }

    pub fn start(self: *HttpBridge) !void {
        const address = std.net.Address.parseIp("127.0.0.1", self.port) catch |err| {
            std.debug.print("\n[HTTP  ]  Error parsing address: {any}", .{err});
            return err;
        };

        var server = try address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("\n[HTTP  ]  Sovereign Bridge active at http://127.0.0.1:{d}", .{self.port});

        while (true) {
            const conn = try server.accept();
            self.handleConnection(conn) catch |err| {
                std.debug.print("\n[HTTP  ]  Connection error: {any}", .{err});
            };
        }
    }

    fn handleConnection(self: *HttpBridge, conn: std.net.Server.Connection) !void {
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = try conn.stream.read(&buf);
        if (bytes_read == 0) return;

        const request = buf[0..bytes_read];
        const first_line = std.mem.sliceTo(request, '\r');
        
        var it = std.mem.splitScalar(u8, first_line, ' ');
        const method = it.next() orelse return;
        const path = it.next() orelse return;

        if (std.mem.eql(u8, method, "OPTIONS")) {
            try self.sendCorsHeader(conn.stream);
            return;
        }

        if (std.mem.eql(u8, path, "/api/v1/network/pulse") or std.mem.eql(u8, path, "/status")) {
            try self.handleStatus(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/wallet/transactions") or std.mem.eql(u8, path, "/ledger")) {
            try self.handleLedger(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/agents/fleet")) {
            try self.handleAgents(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/guardian/pending")) {
            try self.handlePending(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/guardian/approve")) {
            try self.handleApprove(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/audit/attestation")) {
            try self.handleAttestation(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/yield")) {
            try self.handleYield(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/negotiations")) {
            try self.handleNegotiations(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/performance")) {
            try self.handlePerformance(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/wallet/balances")) {
            try self.handleBalances(conn.stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/missions/active")) {
            try self.handleMissions(conn.stream);
        } else {
            try self.sendNotFound(conn.stream);
        }
    }

    fn sendCorsHeader(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        try stream.writeAll("HTTP/1.1 204 No Content\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: *\r\n" ++
            "Connection: close\r\n\r\n");
    }

    fn handleStatus(self: *HttpBridge, stream: std.net.Stream) !void {
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);
        
        const root = self.ctx.store.tree.getRoot();
        const root_hex = std.fmt.bytesToHex(root, .lower);

        const history = try self.ctx.store.getHistory(self.allocator);
        defer {
            for (history) |e| {
                self.allocator.free(e.description);
                self.allocator.free(e.tx_hash);
            }
            self.allocator.free(history);
        }

        var total_gdp: u64 = 0;
        for (history) |e| {
            if (e.entry_type == .receipt) total_gdp += e.amount;
        }

        // Count active local agents + 1 (self)
        const agents_online = self.ctx.active_agents.count() + 1;

        var services_buf = std.ArrayListUnmanaged(u8){};
        defer services_buf.deinit(self.allocator);
        try services_buf.appendSlice(self.allocator, "[");
        for (self.ctx.merchant.services, 0..) |s, i| {
            if (i > 0) try services_buf.appendSlice(self.allocator, ",");
            const s_json = try std.fmt.allocPrint(self.allocator, 
                \\{{"name":"{s}","price":{d},"blink_url":"https://xb77.io/blink/{s}"}}
            , .{ s.name, s.price_lamports, s.name });
            defer self.allocator.free(s_json);
            try services_buf.appendSlice(self.allocator, s_json);
        }
        try services_buf.appendSlice(self.allocator, "]");

        var rules_buf = std.ArrayListUnmanaged(u8){};
        defer rules_buf.deinit(self.allocator);
        try rules_buf.appendSlice(self.allocator, "[");
        if (self.ctx.brain.constitution) |cons| {
            for (cons.rules.items, 0..) |rule, i| {
                if (i > 0) try rules_buf.appendSlice(self.allocator, ",");
                const r_json = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{rule});
                defer self.allocator.free(r_json);
                try rules_buf.appendSlice(self.allocator, r_json);
            }
        }
        try rules_buf.appendSlice(self.allocator, "]");

        const json = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "slot": 250412311,
            \\  "blockHeight": 250411104,
            \\  "agentsOnline": {d},
            \\  "cloudWorkers": 4,
            \\  "proofsVerified24h": {d},
            \\  "ts": {d},
            \\  "agent_id": "{s}",
            \\  "merkle_root": "{s}",
            \\  "agentic_gdp": {d},
            \\  "pending_approvals": {d},
            \\  "merchant": {{ "name": "{s}", "services": {s} }},
            \\  "constitution": {{ "rules": {s} }}
            \\}}
        , .{ agents_online, self.ctx.store.header.total_proofs, std.time.milliTimestamp(), sol_addr, root_hex, total_gdp, self.ctx.pending_authorizations.items.len, self.ctx.merchant.business_name, services_buf.items, rules_buf.items });
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleLedger(self: *HttpBridge, stream: std.net.Stream) !void {
        const history = try self.ctx.store.getHistory(self.allocator);
        defer {
            for (history) |e| {
                self.allocator.free(e.description);
                self.allocator.free(e.tx_hash);
            }
            self.allocator.free(history);
        }

        var json_buf = std.ArrayListUnmanaged(u8){};
        defer json_buf.deinit(self.allocator);

        try json_buf.appendSlice(self.allocator, "{\"transactions\":[");
        for (history, 0..) |e, i| {
            if (i > 0) try json_buf.appendSlice(self.allocator, ",");
            const entry_json = try std.fmt.allocPrint(self.allocator,
                \\{{"ts":{d},"desc":"{s}","amount":{d},"type":"{s}"}}
            , .{ e.timestamp, e.description, e.amount, @tagName(e.entry_type) });
            defer self.allocator.free(entry_json);
            try json_buf.appendSlice(self.allocator, entry_json);
        }
        try json_buf.appendSlice(self.allocator, "]}");

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json_buf.items.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json_buf.items);
    }

    fn handleAgents(self: *HttpBridge, stream: std.net.Stream) !void {
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);

        const json = try std.fmt.allocPrint(self.allocator,
            \\{{"agents":[{{"id":"local-sovereign","pubkey":"{s}","status":"online","pipelines":1,"uptime":1.0}}]}}
        , .{sol_addr});
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handlePending(self: *HttpBridge, stream: std.net.Stream) !void {
        var json_buf = std.ArrayListUnmanaged(u8){};
        defer json_buf.deinit(self.allocator);

        try json_buf.appendSlice(self.allocator, "{\"pending\":[");
        
        // If queue is empty, add a high-value mock for the demo
        if (self.ctx.pending_authorizations.items.len == 0) {
            const mock_json = 
                \\{"id":"auth_777_v1","amount":15000000000,"recipient":"ag_whale_x01","chain":"solana","desc":"Large Arbitrage Deployment","ts":1715000000000}
            ;
            try json_buf.appendSlice(self.allocator, mock_json);
        } else {
            for (self.ctx.pending_authorizations.items, 0..) |p, i| {
                if (i > 0) try json_buf.appendSlice(self.allocator, ",");
                const id_hex = std.fmt.bytesToHex(p.id, .lower);
                const p_json = try std.fmt.allocPrint(self.allocator,
                    \\{{"id":"{s}","amount":{d},"recipient":"{s}","chain":"{s}","desc":"{s}","ts":{d}}}
                , .{ id_hex, p.amount, p.recipient, @tagName(p.chain), p.description, p.ts });
                defer self.allocator.free(p_json);
                try json_buf.appendSlice(self.allocator, p_json);
            }
        }
        try json_buf.appendSlice(self.allocator, "]}");

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json_buf.items.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json_buf.items);
    }

    fn handleApprove(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        // In a real product, we'd parse the ID from the body and process the real tx.
        // For the demo, we return a successful verification signature.
        const json = "{\"ok\":true,\"sig\":\"approved_by_guardian_sig_777777777777\"}";

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleAttestation(self: *HttpBridge, stream: std.net.Stream) !void {
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);

        const root = self.ctx.store.tree.getRoot();
        const root_hex = std.fmt.bytesToHex(root, .lower);
        
        const history = try self.ctx.store.getHistory(self.allocator);
        defer {
            for (history) |e| {
                self.allocator.free(e.description);
                self.allocator.free(e.tx_hash);
            }
            self.allocator.free(history);
        }

        var total_gdp: u64 = 0;
        for (history) |e| {
            if (e.entry_type == .receipt) total_gdp += e.amount;
        }

        const data_to_sign = try std.fmt.allocPrint(self.allocator, "xB77_ATTESTATION:{s}:{d}:{d}", .{ root_hex, total_gdp, std.time.timestamp() });
        defer self.allocator.free(data_to_sign);

        const signature = @import("../security/crypto.zig").sign(data_to_sign, &self.ctx.vaults.ops.sol_kp);
        const sig_hex = std.fmt.bytesToHex(signature, .lower);

        const json = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "agent_id": "{s}",
            \\  "merkle_root": "{s}",
            \\  "agentic_gdp": {d},
            \\  "timestamp": {d},
            \\  "attestation_sig": "{s}",
            \\  "status": "VERIFIED_BY_KERNEL"
            \\}}
        , .{ sol_addr, root_hex, total_gdp, std.time.timestamp(), sig_hex });
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleYield(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        // This would call the Strategist.calculateOptimalYield()
        const json = 
            \\{
            \\  "protocol": "Kamino Finance",
            \\  "strategy": "JupSOL/USDC CLMM",
            \\  "expected_apy": 14.5,
            \\  "risk_score": 0.82,
            \\  "reasoning": "High trading volume in JupSOL pools detected. Increasing fees outweigh IL risk."
            \\}
        ;

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleNegotiations(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        // ... previous implementation ...
        const json = 
            \\{
            \\  "negotiations": [
            \\    {"from": "ag_trader_01", "to": "ag_cfo_alpha", "msg": "AWP_QUOTE_REQ", "payload": "1.2 SOL @ 4h", "status": "sent"},
            \\    {"from": "ag_cfo_alpha", "to": "ag_trader_01", "msg": "AWP_QUOTE_RESP", "payload": "1.15 SOL @ 4h", "status": "counter_offered"},
            \\    {"from": "ag_trader_01", "to": "ag_cfo_alpha", "msg": "AWP_QUOTE_ACCEPT", "payload": "1.15 SOL @ 4h", "status": "accepted"}
            \\  ]
            \\}
        ;

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handlePerformance(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        // High-fidelity performance vector for the Bloomberg-style chart
        const json = 
            \\{
            \\  "pnl_history": [10.2, 12.5, 11.8, 14.2, 16.5, 15.9, 18.4, 21.2, 20.8, 24.5, 27.2, 26.8, 30.1, 34.5, 33.2, 38.4, 42.1, 41.5, 45.8, 49.2, 48.7, 54.2, 58.5, 57.9, 62.4, 66.8, 65.2, 71.4, 75.2, 78.5],
            \\  "yield_efficiency": 94.2,
            \\  "sharpe_ratio": 3.42
            \\}
        ;

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleBalances(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        // In a real product, we'd query the L1/L2 clients.
        // For the deluxe demo, we return a high-fidelity allocation map.
        const json = 
            \\{
            \\  "balances": [
            \\    {"currency": "USDC", "amount": "12,450", "usd": "$12,450.00", "pct": "45%", "color": "#c8ff2e", "rawAmount": 12450},
            \\    {"currency": "SOL", "amount": "85.4", "usd": "$11,240.00", "pct": "40%", "color": "#a78bfa", "rawAmount": 11240},
            \\    {"currency": "USYC", "amount": "1,150", "usd": "$1,150.00", "pct": "15%", "color": "#22d3ee", "rawAmount": 1150}
            \\  ],
            \\  "credits": 1240,
            \\  "tier": "enterprise"
            \\}
        ;

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn handleMissions(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        const json = 
            \\{
            \\  "missions": [
            \\    {
            \\      "id": "mission_alpha_crosschain",
            \\      "goal": "Rebalance 500 USDC to Base for Yield",
            \\      "status": "active",
            \\      "agents": [
            \\        {"id": "ag_solana_01", "role": "Recon", "status": "Identifying Bridge Liquidity"},
            \\        {"id": "ag_base_04", "role": "Executor", "status": "Waiting for inbound AWP_LOCK"},
            \\        {"id": "ag_cfo_alpha", "role": "Guardian", "status": "Risk Check PASSED"}
            \\      ],
            \\      "progress": 65
            \\    }
            \\  ]
            \\}
        ;

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, 
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", 
            .{ json.len }
        );
        try stream.writeAll(header);
        try stream.writeAll(json);
    }

    fn sendNotFound(self: *HttpBridge, stream: std.net.Stream) !void {
        _ = self;
        try stream.writeAll("HTTP/1.1 404 Not Found\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Content-Length: 0\r\n" ++
            "Connection: close\r\n\r\n");
    }
};
