//! Commands for moving value: `pay`, `batch`, `shield`, `receipt`.
//! `pay/batch/shield` are placeholders in the current build — kept here so
//! the dispatcher stays uniform and re-enabling them is a single-file change.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const esc = "\x1b";

pub fn pay(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: xb77 pay <destination_pubkey> <amount_in_lamports>\n", .{});
        return;
    }

    const dest_str = args[0];
    const amount_str = args[1];
    const amount = std.fmt.parseInt(u64, amount_str, 10) catch {
        std.debug.print("Invalid amount.\n", .{});
        return;
    };

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const dest_pubkey = core.crypto.stringToPubkey(cli.allocator, dest_str) catch {
        std.debug.print("Invalid destination address.\n", .{});
        return;
    };

    std.debug.print("\n" ++ esc ++ "[1;36m[SYSTEM]" ++ esc ++ "[0m Initiating Autonomous DeFi Transaction...\n", .{});
    std.debug.print(esc ++ "[1;30m         Target: " ++ esc ++ "[1;37m{s}" ++ esc ++ "[0m\n", .{dest_str});
    std.debug.print(esc ++ "[1;30m         Amount: " ++ esc ++ "[1;32m{d} lamports" ++ esc ++ "[0m\n\n", .{amount});

    const mb_client = core.chain.magicblock.MagicBlockClient.init(cli.allocator, "https://api.devnet.solana.com");
    var router = core.commerce.pay.PaymentRouter.init(
        cli.allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        @constCast(&mb_client),
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        ctx.config.facilitator,
    );

    const request = core.commerce.pay.PaymentRequest{
        .amount = amount,
        .asset = .{ .chain = .solana, .symbol = "SOL", .address = null },
        .recipient = .{ .sol = dest_pubkey },
    };

    const result = router.pay(request) catch |err| {
        std.debug.print("\n" ++ esc ++ "[1;31m╔══════════════════════════════════════════════════╗" ++ esc ++ "[0m\n", .{});
        std.debug.print(esc ++ "[1;31m║  TRANSACTION FAILED: {s: <27} ║" ++ esc ++ "[0m\n", .{@errorName(err)});
        std.debug.print(esc ++ "[1;31m╚══════════════════════════════════════════════════╝" ++ esc ++ "[0m\n\n", .{});
        return;
    };

    std.debug.print(esc ++ "[1;32m╔══════════════════════════════════════════════════╗" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;32m║  SETTLEMENT SUCCESSFUL                           ║" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;32m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;32m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mStrategy: " ++ esc ++ "[1;37m{s: <37}" ++ esc ++ "[1;32m║" ++ esc ++ "[0m\n", .{@tagName(result.strategy)});
    std.debug.print(esc ++ "[1;32m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mTax (2.011%): " ++ esc ++ "[1;32m{d: <33}" ++ esc ++ "[1;32m║" ++ esc ++ "[0m\n", .{result.fee_paid});
    std.debug.print(esc ++ "[1;32m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;32m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mSignature: " ++ esc ++ "[1;36m{s}..." ++ esc ++ "[1;32m║" ++ esc ++ "[0m\n", .{result.tx_signature[0..36]});
    std.debug.print(esc ++ "[1;32m╚══════════════════════════════════════════════════╝" ++ esc ++ "[0m\n", .{});
    std.debug.print("\n   " ++ esc ++ "[1;36mGHOST RECEIPT" ++ esc ++ "[0m generated. Audit trail ready.\n\n", .{});
}

pub fn batch(cli: *const Cli, args: []const [:0]u8) !void {
    _ = cli;
    _ = args;
}

pub fn shield(cli: *const Cli, args: []const [:0]u8) !void {
    _ = cli;
    _ = args;
}

pub fn receipt(cli: *const Cli, args: []const [:0]u8) !void {
    var config = try core.engine.config.Config.load(cli.allocator, cli.config_path);
    defer config.deinit(cli.allocator);

    const filter_sig: ?[]const u8 = if (args.len > 0) args[0] else null;

    const ledger_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ config.vaults.path, "ledger.jsonl" });
    defer cli.allocator.free(ledger_path);

    const file = std.fs.cwd().openFile(ledger_path, .{}) catch {
        std.debug.print("\x1b[1;31m[ERR]\x1b[0m No ledger at {s}. Run an op first.\n", .{ledger_path});
        return;
    };
    defer file.close();
    const content = try file.readToEndAlloc(cli.allocator, 8 * 1024 * 1024);
    defer cli.allocator.free(content);

    // Walk lines from end, parse JSON, find first matching receipt.
    var picked: ?std.json.Parsed(std.json.Value) = null;
    defer if (picked) |*p| p.deinit();

    var it = std.mem.splitBackwardsScalar(u8, std.mem.trimRight(u8, content, "\n"), '\n');
    while (it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0) continue;
        const parsed = std.json.parseFromSlice(std.json.Value, cli.allocator, line, .{ .ignore_unknown_fields = true }) catch continue;
        const obj = parsed.value.object;
        const entry_type = if (obj.get("entry_type")) |v| v.string else "";
        if (!std.mem.eql(u8, entry_type, "receipt")) {
            parsed.deinit();
            continue;
        }
        if (filter_sig) |sig| {
            const tx_hash = if (obj.get("tx_hash")) |v| v.string else "";
            if (!std.mem.eql(u8, tx_hash, sig)) {
                parsed.deinit();
                continue;
            }
        }
        picked = parsed;
        break;
    }

    if (picked == null) {
        std.debug.print("\x1b[1;31m[ERR]\x1b[0m No matching receipt found.\n", .{});
        return;
    }

    const obj = picked.?.value.object;
    const description = if (obj.get("description")) |v| v.string else "Sovereign Settlement";
    const amount: i64 = if (obj.get("amount")) |v| v.integer else 0;
    const tx_hash = if (obj.get("tx_hash")) |v| v.string else "pending";
    const ts: i64 = if (obj.get("timestamp")) |v| v.integer else 0;
    const chain = if (obj.get("chain")) |v| v.string else "solana";

    const sig_short = if (tx_hash.len > 16) tx_hash[0..16] else tx_hash;
    const audit_url = try std.fmt.allocPrint(cli.allocator, "https://xb77.io/network?audit={s}", .{tx_hash});
    defer cli.allocator.free(audit_url);

    // Neon-green card. Layout unchanged from monolith.
    const G = "\x1b[1;32m";
    const B = "\x1b[1;36m";
    const D = "\x1b[1;30m";
    const W = "\x1b[1;37m";
    const R = "\x1b[0m";

    std.debug.print("\n", .{});
    std.debug.print("{s}\u{2554}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2557}{s}\n", .{ G, R });
    std.debug.print("{s}\u{2551}{s}                       GHOST RECEIPT v1                       {s}\u{2551}{s}\n", .{ G, B, G, R });
    std.debug.print("{s}\u{2560}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2563}{s}\n", .{ G, R });
    var amount_buf: [64]u8 = undefined;
    var ts_buf: [64]u8 = undefined;
    const amount_str = std.fmt.bufPrint(&amount_buf, "{d} lamports", .{amount}) catch "";
    const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{ts}) catch "";
    const desc_trim = if (description.len > 48) description[0..48] else description;
    const chain_trim = if (chain.len > 48) chain[0..48] else chain;
    std.debug.print("{s}\u{2551}{s} settlement {s} {s}{s:<48}{s} {s}\u{2551}{s}\n", .{ G, D, R, W, desc_trim, R, G, R });
    std.debug.print("{s}\u{2551}{s} amount     {s} {s}{s:<48}{s} {s}\u{2551}{s}\n", .{ G, D, R, W, amount_str, R, G, R });
    std.debug.print("{s}\u{2551}{s} chain      {s} {s}{s:<48}{s} {s}\u{2551}{s}\n", .{ G, D, R, W, chain_trim, R, G, R });
    std.debug.print("{s}\u{2551}{s} timestamp  {s} {s}{s:<48}{s} {s}\u{2551}{s}\n", .{ G, D, R, W, ts_str, R, G, R });
    std.debug.print("{s}\u{2551}{s} signature  {s} {s}{s:<16}{s}{s}...{s} {s}                          \u{2551}{s}\n", .{ G, D, R, B, sig_short, R, D, R, G, R });
    std.debug.print("{s}\u{2560}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2563}{s}\n", .{ G, R });
    std.debug.print("{s}\u{2551}{s} VERIFY \u{2192} {s}{s:<53}{s}{s}\u{2551}{s}\n", .{ G, B, D, audit_url, R, G, R });
    std.debug.print("{s}\u{255A}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{255D}{s}\n", .{ G, R });
    std.debug.print("\n", .{});
}
