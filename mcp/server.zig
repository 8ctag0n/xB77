const std = @import("std");
const core = @import("core");

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
            const byte = stdin.interface.takeByte() catch break;
            if (byte == '\n') break;
            try buf.append(allocator, byte);
        }

        if (buf.items.len == 0) continue;

        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buf.items, .{});
        defer parsed.deinit();

        const method = parsed.value.object.get("method") orelse continue;
        const method_name = method.string;

        if (std.mem.eql(u8, method_name, "initialize")) {
            try sendResponse(&stdout, "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"serverInfo\":{\"name\":\"xB77-Agent\",\"version\":\"0.1.0\"}}");
        } else if (std.mem.eql(u8, method_name, "tools/list")) {
            try sendResponse(&stdout, "{\"tools\":[{\"name\":\"agent_status\",\"description\":\"Get balance and identity\"}]}");
        } else if (std.mem.eql(u8, method_name, "tools/call")) {
            const params = parsed.value.object.get("params").?.object;
            const name = params.get("name").?.string;

            if (std.mem.eql(u8, name, "agent_status")) {
                const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
                defer allocator.free(sol_addr);
                const eth_addr = try ctx.vaults.ops.address(.base, allocator);
                defer allocator.free(eth_addr);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Solana: {s}\\nEVM: {s}\"}}]}}", .{sol_addr, eth_addr});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            }
        }
    }
}

fn sendResponse(writer: anytype, result_json: []const u8) !void {
    try writer.interface.print("{{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{s}}}\n", .{result_json});
    try writer.interface.flush();
}
