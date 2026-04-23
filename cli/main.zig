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
    } else if (std.mem.eql(u8, command, "batch")) {
        try handleBatch(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "shield")) {
        try handleShield(allocator, args[2..]);
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
        \\  batch <file>     Ejecuta múltiples pagos desde un archivo JSONL
        \\  shield <op>      Gestiona la armadura ZK (whitelist)
        \\                   ops: add <addr>, list, root
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
    var ctx = try core.context.AgentContext.init(allocator, "agent.toml");
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);

    const eth_addr = try ctx.vaults.ops.address(.base, allocator);
    defer allocator.free(eth_addr);

    std.debug.print("\n--- xB77 Agent Status ---\n", .{});
    std.debug.print("Solana: {s}\n", .{sol_addr});
    std.debug.print("Base:   {s}\n", .{eth_addr});

    // Análisis de Ledger (Sovereign Memory)
    const history = try ctx.store.getHistory(allocator);
    defer {
        for (history) |entry| {
            allocator.free(entry.description);
            allocator.free(entry.tx_hash);
        }
        allocator.free(history);
    }
    std.debug.print("\n--- Recent Activity ({d} entries) ---\n", .{history.len});
    const display_count = if (history.len > 5) 5 else history.len;
    if (history.len > 0) {
        for (history[history.len - display_count ..]) |entry| {
            std.debug.print("[{s}] {s}: {d} on {s}\n", .{
                @tagName(entry.entry_type),
                entry.description,
                entry.amount,
                @tagName(entry.chain),
            });
        }
    }
}

fn handlePay(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("Uso: xb77 pay <to> <amount>\n", .{});
        return;
    }
    std.debug.print("Iniciando pago de {s} a {s}...\n", .{args[1], args[0]});
    _ = allocator;
}

fn handleBatch(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 batch <archivo.jsonl>\n", .{});
        return;
    }
    
    var ctx = try core.context.AgentContext.init(allocator, "agent.toml");
    defer ctx.deinit();

    const file_path = args[0];
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    
    std.debug.print("🚀 Procesando ráfaga de pagos desde {s}...\n", .{file_path});
    
    while (true) {
        const amt = try file.read(&buf);
        if (amt == 0) break;
        std.debug.print("📦 Batch chunk processed ({d} bytes).\n", .{amt});
        if (amt < buf.len) break;
    }
}

fn handleShield(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 shield <add|list|root>\n", .{});
        return;
    }

    var ctx = try core.context.AgentContext.init(allocator, "agent.toml");
    defer ctx.deinit();

    const op = args[0];
    if (std.mem.eql(u8, op, "add")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 shield add <direccion>\n", .{});
            return;
        }
        try ctx.compliance.addAddress(args[1]);
        std.debug.print("🛡️ Dirección añadida a la Whitelist ZK.\n", .{});
    } else if (std.mem.eql(u8, op, "list")) {
        std.debug.print("\n--- Whitelist de Cumplimiento (Shield) ---\n", .{});
        for (ctx.compliance.whitelist.items) |addr| {
            std.debug.print("📍 {x}\n", .{addr});
        }
    } else if (std.mem.eql(u8, op, "root")) {
            const root = try ctx.compliance.getRoot();
            const root_hex = try core.crypto.bytesToHex(allocator, &root);
            defer allocator.free(root_hex);
            std.debug.print("\n🛡️ Compliance Merkle Root: {s}\n", .{root_hex});
        }

}

fn handleMcp(allocator: std.mem.Allocator) !void {
    var ctx = try core.context.AgentContext.init(allocator, "agent.toml");
    defer ctx.deinit();

    std.debug.print("Iniciando MCP Server...\n", .{});
    try mcp_server.run(allocator, &ctx);
}

fn handleServe(allocator: std.mem.Allocator) !void {
    var ctx = try core.context.AgentContext.init(allocator, "agent.toml");
    defer ctx.deinit();

    var engine = core.engine.Engine.init(allocator, &ctx);
    try engine.start();
}
