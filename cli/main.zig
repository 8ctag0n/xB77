const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "init")) {
        try handleInit(allocator);
    } else if (std.mem.eql(u8, command, "status")) {
        try handleStatus(allocator);
    } else if (std.mem.eql(u8, command, "pay")) {
        try handlePay(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "mcp")) {
        try handleMcp(allocator);
    } else if (std.mem.eql(u8, command, "serve")) {
        try handleServe(allocator);
    } else {
        std.debug.print("Comando desconocido: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\xB77 — Agent Commerce Infrastructure (Zig Edition)
        \\
        \\Uso: xb77 <comando> [opciones]
        \\
        \\Comandos:
        \\  init             Inicializa el agente y genera su identidad
        \\  status           Muestra el estado y balances del agente
        \\  pay <to> <amt>   Realiza un pago (Solana por defecto)
        \\  mcp              Inicia el servidor de orquestación IA
        \\  serve            Inicia la operación autónoma 24/7
        \\
    , .{});
}

fn handleInit(allocator: std.mem.Allocator) !void {
    std.debug.print("Generando identidad del agente...\n", .{});
    const kp = core.crypto.generateKeypair();
    const addr = try core.crypto.pubkeyToString(allocator, &kp.public);
    defer allocator.free(addr);
    
    std.debug.print("¡Agente inicializado!\n", .{});
    std.debug.print("Dirección Solana: {s}\n", .{addr});
}

fn handleStatus(allocator: std.mem.Allocator) !void {
    var ctx = try core.context.AgentContext.init(allocator, "./.xb77");
    defer ctx.deinit();
    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);
    std.debug.print("--- ESTADO DEL AGENTE ---\nVault (Ops): {s}\n-------------------------\n", .{sol_addr});
}

fn handlePay(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Uso: xb77 pay <destinatario> <monto>\n", .{});
        return;
    }

    const dest_str = args[0];
    const amount_val = std.fmt.parseInt(u64, args[1], 10) catch 0;

    var ctx = try core.context.AgentContext.init(allocator, "./.xb77");
    defer ctx.deinit();

    // Configurar política temporal para la demo
    ctx.vaults.ops.policy = .{
        .daily_limit = 10_000_000_000,
        .per_tx_limit = 5_000_000_000,
        .blacklist = std.AutoHashMap(core.types.Pubkey, void).init(allocator),
    };

    const dest_pubkey = try core.crypto.stringToPubkey(allocator, dest_str);

    std.debug.print("🚀 Ejecutando pago real en Solana Devnet...\n", .{});
    
    var router = core.pay.PaymentRouter.init(allocator, &ctx.sol_client, &ctx.vaults);
    const result = try router.pay(.{
        .amount = amount_val,
        .asset = .{ .chain = .solana, .symbol = "SOL" },
        .recipient = .{ .sol = dest_pubkey },
    });

    std.debug.print("✅ Pago exitoso!\n", .{});
    std.debug.print("Firma: {s}\n", .{result.tx_signature});
}

fn handleMcp(allocator: std.mem.Allocator) !void {
    var ctx = try core.context.AgentContext.init(allocator, "./.xb77");
    defer ctx.deinit();
    try mcp_server.run(allocator, &ctx);
}

fn handleServe(allocator: std.mem.Allocator) !void {
    var ctx = try core.context.AgentContext.init(allocator, "./.xb77");
    defer ctx.deinit();
    var agent_engine = core.engine.Engine.init(allocator, &ctx);
    try agent_engine.start();
}
