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
        const io = std.Io.Threaded.global_single_threaded.io();
        const address = std.Io.net.IpAddress.parseIp4("127.0.0.1", self.port) catch |err| {
            std.debug.print("\n[HTTP  ]  Error parsing address: {any}", .{err});
            return err;
        };

        var server = try address.listen(io, .{ .reuse_address = true });
        defer server.deinit(io);

        std.debug.print("\n[HTTP  ]  Sovereign Bridge active at http://127.0.0.1:{d}", .{self.port});

        while (true) {
            const stream = try server.accept(io);
            self.handleConnection(stream) catch |err| {
                std.debug.print("\n[HTTP  ]  Connection error: {any}", .{err});
            };
        }
    }

    fn handleConnection(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        defer stream.close(io);

        var rb: [4096]u8 = undefined;
        var r = stream.reader(io, &rb);
        var buf: [4096]u8 = undefined;
        const bytes_read = try r.interface.readSliceShort(&buf);
        if (bytes_read == 0) return;

        const request = buf[0..bytes_read];
        const first_line = std.mem.sliceTo(request, '\r');

        var it = std.mem.splitScalar(u8, first_line, ' ');
        const method = it.next() orelse return;
        const path = it.next() orelse return;

        if (std.mem.eql(u8, method, "OPTIONS")) {
            try self.sendCorsHeader(stream);
            return;
        }

        if (std.mem.eql(u8, path, "/api/v1/network/pulse") or std.mem.eql(u8, path, "/status")) {
            try self.handleStatus(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/wallet/transactions") or std.mem.eql(u8, path, "/ledger")) {
            try self.handleLedger(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/agents/fleet")) {
            try self.handleAgents(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/guardian/pending")) {
            try self.handlePending(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/guardian/approve")) {
            try self.handleApprove(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/audit/attestation")) {
            try self.handleAttestation(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/yield")) {
            try self.handleYield(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/negotiations")) {
            try self.handleNegotiations(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/intelligence/performance")) {
            try self.handlePerformance(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/wallet/balances")) {
            try self.handleBalances(stream);
        } else if (std.mem.startsWith(u8, path, "/api/v1/missions/active")) {
            try self.handleMissions(stream);
        } else {
            try self.sendNotFound(stream);
        }
    }

    fn streamWrite(stream: std.Io.net.Stream, data: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        var wb: [65536]u8 = undefined;
        var w = stream.writer(io, &wb);
        try w.interface.writeAll(data);
        try w.interface.flush();
    }

    fn sendResponse(stream: std.Io.net.Stream, header: []const u8, body: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        var wb: [65536]u8 = undefined;
        var w = stream.writer(io, &wb);
        try w.interface.writeAll(header);
        try w.interface.writeAll(body);
        try w.interface.flush();
    }

    fn sendCorsHeader(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
        try streamWrite(stream, "HTTP/1.1 204 No Content\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: *\r\n" ++
            "Connection: close\r\n\r\n");
    }

    fn handleStatus(self: *HttpBridge, stream: std.Io.net.Stream) !void {
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

        var services_buf = std.ArrayListUnmanaged(u8).empty;
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

        var rules_buf = std.ArrayListUnmanaged(u8).empty;
        defer rules_buf.deinit(self.allocator);
        try rules_buf.appendSlice(self.allocator, "[");
        {
            const cons = &self.ctx.constitution;
            for (cons.rules.items, 0..) |rule, i| {
                if (i > 0) try rules_buf.appendSlice(self.allocator, ",");
                const r_json = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{rule});
                defer self.allocator.free(r_json);
                try rules_buf.appendSlice(self.allocator, r_json);
            }
        }
        try rules_buf.appendSlice(self.allocator, "]");

        const io = std.Io.Threaded.global_single_threaded.io();
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
        , .{ agents_online, self.ctx.store.header.total_proofs, std.Io.Timestamp.now(io, .real).toMilliseconds(), sol_addr, root_hex, total_gdp, self.ctx.pending_authorizations.items.len, self.ctx.merchant.business_name, services_buf.items, rules_buf.items });
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleLedger(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        const history = try self.ctx.store.getHistory(self.allocator);
        defer {
            for (history) |e| {
                self.allocator.free(e.description);
                self.allocator.free(e.tx_hash);
            }
            self.allocator.free(history);
        }

        var json_buf = std.ArrayListUnmanaged(u8).empty;
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
            .{json_buf.items.len}
        );
        try sendResponse(stream, header, json_buf.items);
    }

    fn handleAgents(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);

        const json = try std.fmt.allocPrint(self.allocator,
            \\{{"agents":[{{"id":"local-sovereign","pubkey":"{s}","status":"online","pipelines":1,"uptime":1.0}}]}}
        , .{sol_addr});
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handlePending(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        var json_buf = std.ArrayListUnmanaged(u8).empty;
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
            .{json_buf.items.len}
        );
        try sendResponse(stream, header, json_buf.items);
    }

    fn handleApprove(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
        const json = "{\"ok\":true,\"sig\":\"approved_by_guardian_sig_777777777777\"}";

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleAttestation(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
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

        const ts = std.Io.Timestamp.now(io, .real).toSeconds();
        const data_to_sign = try std.fmt.allocPrint(self.allocator, "xB77_ATTESTATION:{s}:{d}:{d}", .{ root_hex, total_gdp, ts });
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
        , .{ sol_addr, root_hex, total_gdp, ts, sig_hex });
        defer self.allocator.free(json);

        var header_buf: [1024]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleYield(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
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
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleNegotiations(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
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
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handlePerformance(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
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
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleBalances(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
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
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn handleMissions(self: *HttpBridge, stream: std.Io.net.Stream) !void {
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
            .{json.len}
        );
        try sendResponse(stream, header, json);
    }

    fn sendNotFound(self: *HttpBridge, stream: std.Io.net.Stream) !void {
        _ = self;
        try streamWrite(stream, "HTTP/1.1 404 Not Found\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Content-Length: 0\r\n" ++
            "Connection: close\r\n\r\n");
    }
};
