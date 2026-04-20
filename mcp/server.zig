const std = @import("std");
const core = @import("core");

const MCP_VERSION = "2024-11-05";

pub fn run(allocator: std.mem.Allocator, ctx: *core.context.AgentContext) !void {
    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;
    
    var stdin = std.fs.File.stdin().reader(&stdin_buf);
    var stdout = std.fs.File.stdout().writer(&stdout_buf);

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    while (true) {
        buf.items.len = 0;
        
        while (true) {
            const byte = stdin.interface.takeByte() catch |err| switch (err) {
                error.EndOfStream => if (buf.items.len == 0) return else break,
                else => return err,
            };
            if (byte == '\n') break;
            try buf.append(allocator, byte);
        }

        if (buf.items.len == 0) continue;

        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buf.items, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;
        const method = obj.get("method") orelse continue;
        const id = obj.get("id");

        if (std.mem.eql(u8, method.string, "initialize")) {
            try sendResponse(&stdout, id, 
                \\{"protocolVersion":"2024-11-05","capabilities":{},"serverInfo":{"name":"xB77-Agent","version":"0.1.0"}}
            );
        } else if (std.mem.eql(u8, method.string, "tools/list")) {
            try sendResponse(&stdout, id, 
                \\{"tools":[
                \\  {"name":"agent_status","description":"Get balance and identity","inputSchema":{"type":"object","properties":{}}},
                \\  {"name":"get_policies","description":"Read spend limits and rules","inputSchema":{"type":"object","properties":{}}},
                \\  {"name":"get_history","description":"Review recent spending","inputSchema":{"type":"object","properties":{}}}
                \\]}
            );
        } else if (std.mem.eql(u8, method.string, "tools/call")) {
            const params = obj.get("params").?.object;
            const name = params.get("name").?.string;

            if (std.mem.eql(u8, name, "agent_status")) {
                const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
                defer allocator.free(sol_addr);
                const response = try std.fmt.allocPrint(allocator, 
                    \\{{"content":[{{"type":"text","text":"Network: Solana Devnet\nOps Vault: {s}\nBalance: 0 SOL"}}]}}
                , .{sol_addr});
                defer allocator.free(response);
                try sendResponse(&stdout, id, response);
            } else if (std.mem.eql(u8, name, "get_policies")) {
                const p = ctx.vaults.ops.policy;
                const response = try std.fmt.allocPrint(allocator, 
                    \\{{"content":[{{"type":"text","text":"Daily Limit: {d} lamports\nPer-Tx Limit: {d} lamports"}}]}}
                , .{p.daily_limit, p.per_tx_limit});
                defer allocator.free(response);
                try sendResponse(&stdout, id, response);
            } else {
                try sendResponse(&stdout, id, 
                    \\{"content":[{"type":"text","text":"Tool not fully implemented yet."}]}
                );
            }
        }
    }
}

fn sendResponse(writer: anytype, id: ?std.json.Value, result_json: []const u8) !void {
    try writer.interface.print("{{\"jsonrpc\":\"2.0\",", .{});
    if (id) |v| {
        try writer.interface.print("\"id\":{any},", .{std.json.fmt(v, .{})});
    } else {
        try writer.interface.print("\"id\":null,", .{});
    }
    try writer.interface.print("\"result\":{s}}}\n", .{result_json});
    try writer.interface.flush();
}
