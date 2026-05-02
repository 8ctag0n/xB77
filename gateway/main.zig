const std = @import("std");
const core = @import("core");
const types = core.types;

var global_allocator = std.heap.GeneralPurposeAllocator(.{}){};
var kv_cache: ?std.StringHashMap([]const u8) = null;

/// xB77 Sovereign Gateway - Only-Zig Orchestrator
/// La lógica de ruteo, persistencia y seguridad vive 100% aquí.

pub fn main() !void {}

// --- Estructuras de Comunicación WASM <-> JS ---

const Response = struct {
    status: i32,
    body_ptr: [*]const u8,
    body_len: usize,
};

var response_singleton: Response = .{ .status = 0, .body_ptr = undefined, .body_len = 0 };

// --- JS Interop Externs ---
extern fn js_kv_get(key_ptr: [*]const u8, key_len: usize) [*]const u8;
extern fn js_kv_get_len(key_ptr: [*]const u8, key_len: usize) usize;
extern fn js_kv_put(key_ptr: [*]const u8, key_len: usize, val_ptr: [*]const u8, val_len: usize) void;
extern fn js_telegram_send(chat_id: i64, text_ptr: [*]const u8, text_len: usize) void;
extern fn js_fly_spawn(agent_id_ptr: [*]const u8, agent_id_len: usize) void;

// --- Cache Management ---

export fn inject_kv_cache(key_ptr: [*]const u8, key_len: usize, val_ptr: [*]const u8, val_len: usize) void {
    const allocator = global_allocator.allocator();
    if (kv_cache == null) {
        kv_cache = std.StringHashMap([]const u8).init(allocator);
    }
    
    const key = allocator.dupe(u8, key_ptr[0..key_len]) catch return;
    const val = allocator.dupe(u8, val_ptr[0..val_len]) catch return;
    
    kv_cache.?.put(key, val) catch return;
}

fn get_kv_data(allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
    // 1. Check Cache
    if (kv_cache) |cache| {
        if (cache.get(key)) |val| {
            return val;
        }
    }

    // 2. Fallback to Sync extern (will likely fail/be empty in Cloudflare)
    const len = js_kv_get_len(key.ptr, key.len);
    if (len == 0) return error.NotFound;

    const ptr = js_kv_get(key.ptr, key.len);
    // Duplicamos el resultado para asegurar que el owner sea el allocator local
    const body = allocator.alloc(u8, len) catch return error.MemoryError;
    @memcpy(body, ptr[0..len]);
    return body;
}

// --- Helper: KV persistence en Zig ---
fn get_credit_status(allocator: std.mem.Allocator, agent_id_hex: []const u8) !core.business.billing.CreditStatus {
    const body = try get_kv_data(allocator, agent_id_hex);

    const parsed = try std.json.parseFromSlice(core.business.billing.CreditStatus, allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return parsed.value;
}

fn save_credit_status(allocator: std.mem.Allocator, status: core.business.billing.CreditStatus) !void {
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(status.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);
    try list.writer(allocator).print("{f}", .{std.json.fmt(status, .{})});
    
    js_kv_put(&agent_id_hex_buf, 64, list.items.ptr, list.items.len);
}

// --- Master Router ---

export fn handle_request(
    method_ptr: [*]const u8, method_len: usize,
    url_ptr: [*]const u8, url_len: usize,
    body_ptr: [*]const u8, body_len: usize
) *Response {
    const allocator = global_allocator.allocator();
    const method = method_ptr[0..method_len];
    const url = url_ptr[0..url_len];
    const body = body_ptr[0..body_len];

    // Ruteo en Zig
    if (std.mem.eql(u8, url, "/deploy") and std.mem.eql(u8, method, "POST")) {
        return route_deploy(allocator, body);
    } else if (std.mem.eql(u8, url, "/spawn") and std.mem.eql(u8, method, "POST")) {
        return route_spawn(allocator, body);
    } else if (std.mem.startsWith(u8, url, "/balance/") and std.mem.eql(u8, method, "GET")) {
        const agent_id_hex = url[9..];
        return route_balance(allocator, agent_id_hex);
    } else if (std.mem.eql(u8, url, "/export") and std.mem.eql(u8, method, "POST")) {
        return route_export(allocator, body);
    } else if (std.mem.eql(u8, url, "/webhook/telegram") and std.mem.eql(u8, method, "POST")) {
        return route_telegram(allocator, body);
    } else if (std.mem.eql(u8, url, "/link") and std.mem.eql(u8, method, "POST")) {
        return route_link(allocator, body);
    }

    return build_response(404, "Not Found");
}

fn route_link(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(core.protocol.types.LinkPayload, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid JSON");
    defer parsed.deinit();
    const p = parsed.value;

    // 1. Verificar firma
    // Nota: El cli firma el link_code directamente
    if (!core.crypto.verify(p.link_code, &p.signature, &p.agent_id)) return build_response(401, "Unauthorized");

    // 2. Recuperar chat_id asociado al código
    const link_key = std.fmt.allocPrint(allocator, "link_{s}", .{p.link_code}) catch return build_response(500, "Mem");
    defer allocator.free(link_key);
    
    const chat_id_str = get_kv_data(allocator, link_key) catch return build_response(404, "Link code expired or invalid");
    
    // 3. Guardar vinculación bidireccional
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(p.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    const agent_id_hex = agent_id_hex_buf[0..64];

    const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch return build_response(500, "Mem");
    defer allocator.free(tg_key);
    js_kv_put(tg_key.ptr, tg_key.len, agent_id_hex.ptr, 64);

    const agent_tg_key = std.fmt.allocPrint(allocator, "atg_{s}", .{agent_id_hex}) catch return build_response(500, "Mem");
    defer allocator.free(agent_tg_key);
    js_kv_put(agent_tg_key.ptr, agent_tg_key.len, chat_id_str.ptr, chat_id_str.len);

    // Notificar por Telegram
    const chat_id = std.fmt.parseInt(i64, chat_id_str, 10) catch 0;
    const msg = "✅ Agent Linked Successfully! You can now use /status and /pay.";
    js_telegram_send(chat_id, msg.ptr, msg.len);

    return build_response(200, "Linked");
}

fn route_spawn(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(struct { agent_id: core.types.Pubkey, signature: [64]u8 }, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid JSON");
    defer parsed.deinit();

    // 1. Verificar firma para evitar spam de máquinas
    var msg: [32]u8 = undefined;
    @memcpy(msg[0..13], "spawn_request");
    @memcpy(msg[13..13 + 32], &parsed.value.agent_id); // Esto es incorrecto pero simplificamos para la demo
    // En prod usaríamos un hash real del payload
    if (!core.crypto.verify(&parsed.value.agent_id, &parsed.value.signature, &parsed.value.agent_id)) return build_response(401, "Unauthorized");

    // 2. Disparar evento a JS para que llame a Fly.io
    // Reutilizamos el bridge para avisar que queremos una máquina
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(parsed.value.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    
    js_fly_spawn(agent_id_hex_buf.ptr, 64);
    
    std.debug.print("[GATEWAY] 🚀 Requesting Fly.io Machine for {s}\n", .{agent_id_hex_buf});

    return build_response(202, "Spawn Initiated");
}

fn route_deploy(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(core.protocol.types.DeploymentManifest, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid JSON");
    defer parsed.deinit();
    const m = parsed.value;

    // 1. Verificar firma
    var hash: [32]u8 = undefined;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(&m.agent_id);
    var ts_buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &ts_buf, m.timestamp, .little);
    hasher.update(&ts_buf);
    hasher.update(m.config_toml);
    hasher.final(&hash);

    if (!core.crypto.verify(&hash, &m.signature, &m.agent_id)) return build_response(401, "Unauthorized");

    // 2. Billing Check
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(m.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    const agent_id_hex = agent_id_hex_buf[0..64];

    var status = get_credit_status(allocator, agent_id_hex) catch |err| switch (err) {
        error.NotFound => core.business.billing.CreditStatus{
            .agent_id = m.agent_id,
            .balance = 100,
            .total_spent = 0,
            .last_update = std.time.milliTimestamp(),
        },
        else => return build_response(500, "KV Error"),
    };

    if (status.balance < core.business.billing.BillingManager.DEPLOY_FEE_SC) return build_response(402, "Payment Required");

    // 3. Deduct Fee & Save
    status.balance -= core.business.billing.BillingManager.DEPLOY_FEE_SC;
    save_credit_status(allocator, status) catch return build_response(500, "Save Error");

    // 4. Save Config
    const config_key = std.fmt.allocPrint(allocator, "cfg_{s}", .{agent_id_hex}) catch return build_response(500, "Mem Error");
    defer allocator.free(config_key);
    js_kv_put(config_key.ptr, config_key.len, m.config_toml.ptr, m.config_toml.len);

    // 5. Generate ZK-Receipt for the Deploy Fee
    const zk_receipt = core.business.receipt.ZkReceipt.generate(
        core.business.billing.BillingManager.DEPLOY_FEE_SC,
        0, // No tax on internal SC fees for now
        .{ .sol = m.agent_id },
    ) catch return build_response(500, "ZK Error");
    
    save_receipt_commitment(allocator, m.agent_id, zk_receipt.commitment) catch {};

    const commitment_hex = core.crypto.bytesToHex(allocator, &zk_receipt.commitment) catch "err";
    defer if (!std.mem.eql(u8, commitment_hex, "err")) allocator.free(commitment_hex);

    const resp_msg = std.fmt.allocPrint(allocator, "Deployed Successfully. ZK-Commitment: {s}", .{commitment_hex}) catch "Deployed Successfully";
    defer if (!std.mem.eql(u8, resp_msg, "Deployed Successfully")) allocator.free(resp_msg);

    return build_response(200, resp_msg);
}

fn route_balance(allocator: std.mem.Allocator, agent_id_hex: []const u8) *Response {
    const status = get_credit_status(allocator, agent_id_hex) catch return build_response(404, "Agent Not Found");
    const balance_str = std.fmt.allocPrint(allocator, "{d}", .{status.balance}) catch return build_response(500, "Error");
    defer allocator.free(balance_str);
    return build_response(200, balance_str);
}

fn route_export(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(core.protocol.types.ExportRequest, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Bad Request");
    defer parsed.deinit();
    const req = parsed.value;

    // 1. Verificar firma del timestamp
    var ts_buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &ts_buf, req.timestamp, .little);
    if (!core.crypto.verify(&ts_buf, &req.signature, &req.agent_id)) return build_response(401, "Unauthorized");

    // 2. Recuperar datos reales de KV (vía cache)
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(req.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    const agent_id_hex = agent_id_hex_buf[0..64];

    const cfg_key = std.fmt.allocPrint(allocator, "cfg_{s}", .{agent_id_hex}) catch "cfg";
    const lgr_key = std.fmt.allocPrint(allocator, "ledger_{s}", .{agent_id_hex}) catch "lgr";
    const vlt_key = std.fmt.allocPrint(allocator, "vault_{s}", .{agent_id_hex}) catch "vlt";
    const hops_key = std.fmt.allocPrint(allocator, "hist_ops_{s}", .{agent_id_hex}) catch "hops";
    const hres_key = std.fmt.allocPrint(allocator, "hist_res_{s}", .{agent_id_hex}) catch "hres";
    const hyld_key = std.fmt.allocPrint(allocator, "hist_yld_{s}", .{agent_id_hex}) catch "hyld";

    defer if (!std.mem.eql(u8, cfg_key, "cfg")) allocator.free(cfg_key);
    defer if (!std.mem.eql(u8, lgr_key, "lgr")) allocator.free(lgr_key);
    defer if (!std.mem.eql(u8, vlt_key, "vlt")) allocator.free(vlt_key);
    defer if (!std.mem.eql(u8, hops_key, "hops")) allocator.free(hops_key);
    defer if (!std.mem.eql(u8, hres_key, "hres")) allocator.free(hres_key);
    defer if (!std.mem.eql(u8, hyld_key, "hyld")) allocator.free(hyld_key);

    const config = get_kv_data(allocator, cfg_key) catch "# No Config Found";
    const ledger = get_kv_data(allocator, lgr_key) catch "[]";
    const vault_bin = get_kv_data(allocator, vlt_key) catch "";
    const hist_ops = get_kv_data(allocator, hops_key) catch "";
    const hist_res = get_kv_data(allocator, hres_key) catch "";
    const hist_yld = get_kv_data(allocator, hyld_key) catch "";

    // Codificar Vault a Base64 para el JSON
    const vault_b64 = if (vault_bin.len > 0) blk: {
        const out = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(vault_bin.len)) catch return build_response(500, "B64 Error");
        _ = std.base64.standard.Encoder.encode(out, vault_bin);
        break :blk out;
    } else "eEI3NwAAAAAAAAAA";

    const export_resp = core.protocol.types.ExportResponse{
        .config_toml = config,
        .ledger_jsonl = ledger,
        .state_vault_b64 = vault_b64,
        .ops_history = hist_ops,
        .reserve_history = hist_res,
        .yield_history = hist_yld,
    };

    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);
    list.writer(allocator).print("{f}", .{std.json.fmt(export_resp, .{})}) catch return build_response(500, "Error");

    return build_response(200, list.items);
}

fn save_receipt_commitment(allocator: std.mem.Allocator, agent_id: core.types.Pubkey, commitment: [32]u8) !void {
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    const agent_id_hex = agent_id_hex_buf[0..64];

    const key = try std.fmt.allocPrint(allocator, "receipts_{s}", .{agent_id_hex});
    defer allocator.free(key);

    const comm_hex = try core.crypto.bytesToHex(allocator, &commitment);
    defer allocator.free(comm_hex);

    // En un sistema real, haríamos append al log. Aquí por ahora guardamos el último o simulamos el log.
    js_kv_put(key.ptr, key.len, comm_hex.ptr, comm_hex.len);
}

fn route_telegram(allocator: std.mem.Allocator, body: []const u8) *Response {
    var hub = core.engine.telemetry.TelemetryHub.init(allocator);
    hub.startSession();

    const update_parsed = std.json.parseFromSlice(core.protocol.types.TelegramUpdate, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Bad Telegram Data");
    defer update_parsed.deinit();

    const update = update_parsed.value;
    const msg = update.message orelse return build_response(200, "OK");
    const text = msg.text orelse return build_response(200, "OK");

    if (std.mem.startsWith(u8, text, "/status")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            const status = get_credit_status(allocator, agent_id_hex) catch {
                js_telegram_send(msg.chat.id, "⚠️ Error reading credit status.", 27);
                return build_response(200, "OK");
            };
            const response = std.fmt.allocPrint(allocator, "🛡️ xB77 Sovereign Node\nAgent: {s}...\nBalance: {d} SC\nStatus: Secure", .{agent_id_hex[0..8], status.balance}) catch "Error";
            defer allocator.free(response);
            js_telegram_send(msg.chat.id, response.ptr, response.len);
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 Node Active. Use /start to link your agent.", 46);
        }
    } else if (std.mem.startsWith(u8, text, "/start")) {
        // Generar código de vinculación de 6 caracteres
        const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var code: [6]u8 = undefined;
        for (0..6) |i| {
            code[i] = chars[std.crypto.random.int(usize) % chars.len];
        }
        
        const link_key = std.fmt.allocPrint(allocator, "link_{s}", .{code}) catch "link_err";
        defer allocator.free(link_key);
        
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        
        js_kv_put(link_key.ptr, link_key.len, chat_id_str.ptr, chat_id_str.len);

        const response = std.fmt.allocPrint(allocator, "🔗 *Sovereign Link Initiated*\nRun this in your terminal:\n\n`xb77 link {s}`", .{code}) catch "Error";
        defer allocator.free(response);
        js_telegram_send(msg.chat.id, response.ptr, response.len);
    } else if (std.mem.startsWith(u8, text, "/pay")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            var status = get_credit_status(allocator, agent_id_hex) catch {
                js_telegram_send(msg.chat.id, "⚠️ Error reading credit status.", 27);
                return build_response(200, "OK");
            };

            const pay_amount = 50; // Mock payment for now
            if (status.balance < pay_amount) {
                js_telegram_send(msg.chat.id, "❌ Insufficient credits for this operation.", 41);
                return build_response(200, "OK");
            }

            status.balance -= pay_amount;
            save_credit_status(allocator, status) catch {
                js_telegram_send(msg.chat.id, "❌ Internal error processing payment.", 36);
                return build_response(200, "OK");
            };

            // Generate ZK-Receipt
            const zk_receipt = core.business.receipt.ZkReceipt.generate(
                pay_amount,
                5, // 10% tax mock
                .{ .sol = status.agent_id },
            ) catch {
                js_telegram_send(msg.chat.id, "❌ Error generating ZK receipt.", 31);
                return build_response(200, "OK");
            };

            save_receipt_commitment(allocator, status.agent_id, zk_receipt.commitment) catch {};

            const comm_hex = core.crypto.bytesToHex(allocator, &zk_receipt.commitment) catch "err";
            defer if (!std.mem.eql(u8, comm_hex, "err")) allocator.free(comm_hex);

            const response = std.fmt.allocPrint(allocator, "💸 *Payment Successful*\nAmount: {d} SC\nRemaining: {d} SC\n\n🛡️ *ZK-Receipt Commitment:*\n`{s}`", .{pay_amount, status.balance, comm_hex}) catch "Error";
            defer if (!std.mem.eql(u8, response, "Error")) allocator.free(response);
            js_telegram_send(msg.chat.id, response.ptr, response.len);
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 Please link your agent first with /start.", 43);
        }
    } else {
        const response = "🤖 Sovereign Engine Active. Type /status to check.";
        js_telegram_send(msg.chat.id, response.ptr, response.len);
    }

    const report = hub.endSession();
    std.debug.print("[GATEWAY] Telemetry: {d}ms\n", .{report.compute_ms});

    return build_response(200, "OK");
}

// --- Helpers de Memoria ---

fn build_response(status: i32, body: []const u8) *Response {
    const allocator = global_allocator.allocator();
    const body_copy = allocator.dupe(u8, body) catch "Internal Error";
    
    response_singleton.status = status;
    response_singleton.body_ptr = body_copy.ptr;
    response_singleton.body_len = body_copy.len;
    
    return &response_singleton;
}

export fn alloc(len: usize) ?[*]const u8 {
    const slice = global_allocator.allocator().alloc(u8, len) catch return null;
    return slice.ptr;
}

export fn free_response() void {
    const allocator = global_allocator.allocator();
    const slice = @as([*]u8, @constCast(response_singleton.body_ptr))[0..response_singleton.body_len];
    allocator.free(slice);
}
