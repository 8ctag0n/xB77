const std = @import("std");
const core = @import("core");

pub const LinkCmd = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
        if (args.len < 1) {
            std.debug.print("Usage: xb77 link <CODE>\n", .{});
            return;
        }
        const code = args[0];

        // 1. Initialize core context to load identity
        const config = try core.kernel.config.AgentConfig.loadDefault(allocator);
        var vaults = try core.security.vault.VaultSet.init(allocator, config.vaults.path, "default"); // Assuming default pass for local dev
        defer vaults.deinit(allocator);
        const sol_keypair = try vaults.ops.keypair(.solana, allocator);
        
        var pubkey_buf: [32]u8 = undefined;
        @memcpy(&pubkey_buf, sol_keypair[32..]); // Pubkey is last 32 bytes

        // 2. Sign the link code
        const signature = core.crypto.sign(code, sol_keypair);

        // 3. Prepare payload
        const payload = core.protocol.types.LinkPayload{
            .agent_id = pubkey_buf,
            .link_code = code,
            .signature = signature,
        };

        var json_buf = std.ArrayListUnmanaged(u8).empty;
        defer json_buf.deinit(allocator);
        try std.json.stringify(payload, .{}, json_buf.writer(allocator));

        // 4. Send to Gateway
        std.debug.print("Initiating Sovereign Link via Cloudflare Edge...\n", .{});
        
        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        var req = try client.open(.POST, try std.Uri.parse("https://gateway.xb77.io/api/v1/actions/link_agent"));
        defer req.deinit();

        req.transfer_encoding = .chunked;
        try req.send();
        try req.writeAll(json_buf.items);
        try req.finish();
        try req.wait();

        if (req.response.status == .ok) {
            std.debug.print("\n[SUCCESS] Agent linked successfully to Web/Telegram Dashboard!\n", .{});
        } else {
            std.debug.print("\n[ERROR] Link failed: {d}\n", .{req.response.status});
        }
    }
};
