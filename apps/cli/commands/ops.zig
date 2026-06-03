//! Commands for moving value: `pay`, `batch`, `shield`, `receipt`.
//! `pay/batch/shield` are placeholders in the current build — kept here so
//! the dispatcher stays uniform and re-enabling them is a single-file change.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const esc = "\x1b";
const LIME = esc ++ "[1;32m";
const CYAN = esc ++ "[1;36m";
const GOLD = esc ++ "[1;33m";
const MAG = esc ++ "[1;35m";
const DIM = esc ++ "[1;30m";
const WHT = esc ++ "[1;37m";
const RED = esc ++ "[1;31m";
const RST = esc ++ "[0m";

pub fn pay(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print(DIM ++ "Usage: " ++ RST ++ WHT ++ "xb77 pay <dest_pk> <amount>\n" ++ RST, .{});
        return;
    }

    const dest_str = args[0];
    const amount_str = args[1];
    const amount = std.fmt.parseInt(u64, amount_str, 10) catch {
        std.debug.print(RED ++ "Error: Monto inválido.\n" ++ RST, .{});
        return;
    };

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const dest_pubkey = core.crypto.stringToPubkey(cli.allocator, dest_str) catch {
        std.debug.print(RED ++ "Error: Pubkey de destino inválida.\n" ++ RST, .{});
        return;
    };

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "DeFi" ++ CYAN ++ "]" ++ RST ++ " INICIANDO_TRANSFERENCIA_AUTÓNOMA...\n", .{});
    std.debug.print(DIM ++ "         Target: " ++ RST ++ WHT ++ "{s}\n", .{dest_str});
    std.debug.print(DIM ++ "         Amount: " ++ RST ++ LIME ++ "{d} lamports\n\n", .{amount});

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
        std.debug.print("\n" ++ RED ++ "╔══════════════════════════════════════════════════╗" ++ RST ++ "\n", .{});
        std.debug.print(RED ++ "║  TRANSACCIÓN FALLIDA: " ++ WHT ++ "{s: <27}" ++ RED ++ "║" ++ RST ++ "\n", .{@errorName(err)});
        std.debug.print(RED ++ "╚══════════════════════════════════════════════════╝" ++ RST ++ "\n\n", .{});
        return;
    };

    std.debug.print(LIME ++ "╔══════════════════════════════════════════════════╗" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║  SETTLEMENT_SUCCESSFUL                           ║" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "╠══════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Estrategia:" ++ RST ++ " " ++ WHT ++ "{s: <36}" ++ LIME ++ "║" ++ RST ++ "\n", .{@tagName(result.strategy)});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Tax (2.011%):" ++ RST ++ " " ++ LIME ++ "{d: <33}" ++ LIME ++ "║" ++ RST ++ "\n", .{result.fee_paid});
    std.debug.print(LIME ++ "╠══════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Signature:" ++ RST ++ " " ++ CYAN ++ "{s}..." ++ LIME ++ "║" ++ RST ++ "\n", .{result.tx_signature[0..36]});
    std.debug.print(LIME ++ "╚══════════════════════════════════════════════════╝" ++ RST ++ "\n", .{});
    std.debug.print("\n   " ++ CYAN ++ "GHOST_RECEIPT" ++ RST ++ " generado. Memoria anclada.\n\n", .{});
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

    const file = std.Io.Dir.cwd().openFile(std.Io.Threaded.global_single_threaded.io(), ledger_path, .{}) catch {
        std.debug.print(RED ++ "[ERR]" ++ RST ++ " No se encontró el ledger en {s}.\n", .{ledger_path});
        return;
    };
    defer file.close(std.Io.Threaded.global_single_threaded.io());
    const content = try file.readToEndAlloc(cli.allocator, 8 * 1024 * 1024);
    defer cli.allocator.free(content);

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
        std.debug.print(RED ++ "[ERR]" ++ RST ++ " Recibo no encontrado.\n", .{});
        return;
    }

    const obj = picked.?.value.object;
    const description = if (obj.get("description")) |v| v.string else "Sovereign Settlement";
    const amount: i64 = if (obj.get("amount")) |v| v.integer else 0;
    const tx_hash = if (obj.get("tx_hash")) |v| v.string else "pending";
    const ts: i64 = if (obj.get("timestamp")) |v| v.integer else 0;
    const chain = if (obj.get("chain")) |v| v.string else "solana";

    const audit_url = try std.fmt.allocPrint(cli.allocator, "https://xb77.io/network?audit={s}", .{tx_hash});
    defer cli.allocator.free(audit_url);

    std.debug.print("\n", .{});
    std.debug.print(LIME ++ "╔══════════════════════════════════════════════════════════════╗" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ "                   " ++ CYAN ++ "GHOST_RECEIPT_V1" ++ RST ++ "                     " ++ LIME ++ "║" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "╠══════════════════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "SETTLEMENT:" ++ RST ++ " " ++ WHT ++ "{s: <48}" ++ LIME ++ "║" ++ RST ++ "\n", .{if (description.len > 48) description[0..48] else description});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "AMOUNT:" ++ RST ++ "     " ++ LIME ++ "{d: <48}" ++ LIME ++ "║" ++ RST ++ "\n", .{amount});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "CHAIN:" ++ RST ++ "      " ++ MAG ++ "{s: <48}" ++ LIME ++ "║" ++ RST ++ "\n", .{chain});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "TIMESTAMP:" ++ RST ++ "  " ++ WHT ++ "{d: <48}" ++ LIME ++ "║" ++ RST ++ "\n", .{ts});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "SIGNATURE:" ++ RST ++ "  " ++ CYAN ++ "{s}..." ++ LIME ++ "║" ++ RST ++ "\n", .{tx_hash[0..@min(tx_hash.len, 44)]});
    std.debug.print(LIME ++ "╠══════════════════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ " " ++ WHT ++ "VERIFY_ZK:" ++ RST ++ "  " ++ DIM ++ "{s: <48}" ++ LIME ++ "║" ++ RST ++ "\n", .{audit_url[0..@min(audit_url.len, 48)]});
    std.debug.print(LIME ++ "╚══════════════════════════════════════════════════════════════╝" ++ RST ++ "\n\n", .{});
}
