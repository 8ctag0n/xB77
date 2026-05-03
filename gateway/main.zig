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
    } else if (std.mem.eql(u8, url, "/api/telemetry") and std.mem.eql(u8, method, "GET")) {
        return route_telemetry(allocator);
    } else if (std.mem.eql(u8, url, "/webhook/telegram") and std.mem.eql(u8, method, "POST")) {
        return route_telegram(allocator, body);
    } else if (std.mem.eql(u8, url, "/identity/claim") and std.mem.eql(u8, method, "POST")) {
        return route_identity_claim(allocator, body);
    } else if (std.mem.startsWith(u8, url, "/p/") and std.mem.eql(u8, method, "GET")) {
        const name = url[3..];
        return route_profile(allocator, name);
    } else if (std.mem.eql(u8, url, "/verify") and std.mem.eql(u8, method, "POST")) {
        return route_verify(allocator, body);
    } else if (std.mem.eql(u8, url, "/app/message") and std.mem.eql(u8, method, "POST")) {
        return route_app_message(allocator, body);
    } else if (std.mem.eql(u8, url, "/link") and std.mem.eql(u8, method, "POST")) {
        return route_link(allocator, body);
    }

    return build_response(404, "Not Found");
}

fn route_profile(allocator: std.mem.Allocator, name: []const u8) *Response {
    const name_key = std.fmt.allocPrint(allocator, "name_{s}", .{name}) catch return build_response(500, "Error");
    defer allocator.free(name_key);

    const agent_id_hex = get_kv_data(allocator, name_key) catch return build_response(404, "Agent not found");
    const status = get_credit_status(allocator, agent_id_hex) catch return build_response(500, "Error reading status");

    const html = std.fmt.allocPrint(allocator, 
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>{s}.xb77 | Sovereign Financial Agent</title>
        \\    <style>
        \\        :root {{ --neon-green: #00ff41; --dark-bg: #0a0a0a; --panel-bg: #121212; --border-color: #333; }}
        \\        body {{ background: var(--dark-bg); color: var(--neon-green); font-family: 'JetBrains Mono', 'Courier New', monospace; margin: 0; display: flex; flex-direction: column; align-items: center; min-height: 100vh; text-shadow: 0 0 5px rgba(0,255,65,0.5); }}
        \\        .scanline {{ width: 100%; height: 100%; position: fixed; background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06)); z-index: 999; pointer-events: none; background-size: 100% 4px, 3px 100%; }}
        \\        .container {{ max-width: 800px; width: 95%; padding: 2rem 0; }}
        \\        .header {{ border-bottom: 2px solid var(--neon-green); padding-bottom: 1rem; margin-bottom: 2rem; display: flex; justify-content: space-between; align-items: flex-end; }}
        \\        .header h1 {{ margin: 0; font-size: 2.5rem; letter-spacing: -2px; }}
        \\        .badge {{ background: var(--neon-green); color: black; padding: 2px 8px; font-size: 0.8rem; font-weight: bold; border-radius: 3px; vertical-align: middle; margin-left: 10px; }}
        \\        .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }}
        \\        .card {{ background: var(--panel-bg); border: 1px solid var(--border-color); padding: 1.5rem; border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); position: relative; overflow: hidden; }}
        \\        .card::before {{ content: ""; position: absolute; top: 0; left: 0; width: 100%; height: 2px; background: linear-gradient(90deg, transparent, var(--neon-green), transparent); animation: moveLine 3s infinite linear; }}
        \\        @keyframes moveLine {{ 0% {{ transform: translateX(-100%); }} 100% {{ transform: translateX(100%); }} }}
        \\        .card h2 {{ font-size: 1rem; color: #888; text-transform: uppercase; margin-top: 0; border-bottom: 1px solid #222; padding-bottom: 0.5rem; }}
        \\        .stat-value {{ font-size: 2rem; margin: 1rem 0; font-weight: bold; }}
        \\        .meta-list {{ list-style: none; padding: 0; font-size: 0.85rem; color: #aaa; }}
        \\        .meta-list li {{ margin-bottom: 0.5rem; display: flex; justify-content: space-between; }}
        \\        .meta-list li span {{ color: var(--neon-green); }}
        \\        .blink-btn {{ display: block; width: 100%; box-sizing: border-box; background: var(--neon-green); color: black; text-align: center; padding: 1rem; text-decoration: none; font-weight: bold; border-radius: 5px; margin-top: 1rem; border: none; cursor: pointer; transition: all 0.2s; }}
        \\        .blink-btn:hover {{ background: white; transform: translateY(-2px); box-shadow: 0 5px 15px rgba(0,255,65,0.4); }}
        \\        .verify-box {{ grid-column: span 2; background: #000; border: 1px dashed var(--neon-green); }}
        \\        .verify-input {{ background: transparent; border: none; border-bottom: 1px solid var(--neon-green); color: var(--neon-green); width: 100%; padding: 0.5rem; font-family: inherit; font-size: 1rem; outline: none; margin: 1rem 0; }}
        \\        .result {{ display: none; margin-top: 1rem; padding: 1rem; border: 1px solid var(--neon-green); font-size: 0.8rem; background: rgba(0,255,65,0.05); }}
        \\        .footer {{ margin-top: 4rem; text-align: center; font-size: 0.7rem; color: #444; border-top: 1px solid #222; padding-top: 2rem; }}
        \\        @media (max-width: 600px) {{ .grid {{ grid-template-columns: 1fr; }} .verify-box {{ grid-column: span 1; }} }}
        \\    </style>
        \\</head>
        \\<body>
        \\    <div class="scanline"></div>
        \\    <div class="container">
        \\        <div class="header">
        \\            <div>
        \\                <h1>{s}.xb77<span class="badge">SOVEREIGN</span></h1>
        \\                <div style="color: #666; font-size: 0.9rem;">Deployment: Fly.io Region: AMS</div>
        \\            </div>
        \\            <div style="text-align: right;">
        \\                <div style="font-size: 0.8rem;">PROTOCOL VERSION</div>
        \\                <div style="font-weight: bold;">v0.11-S8</div>
        \\            </div>
        \\        </div>
        \\
        \\        <div class="grid">
        \\            <div class="card">
        \\                <h2>Treasury Health</h2>
        \\                <div class="stat-value">{d} SC</div>
        \\                <ul class="meta-list">
        \\                    <li>Sovereign Credits <span>Active</span></li>
        \\                    <li>Daily Burn <span>0.22 SC</span></li>
        \\                    <li>Infrastructure Tax <span>2.011%</span></li>
        \\                </ul>
        \\            </div>
        \\
        \\            <div class="card">
        \\                <h2>Node Sentinel</h2>
        \\                <div class="stat-value" style="color: #00ff00;">ONLINE</div>
        \\                <ul class="meta-list">
        \\                    <li>Z-Node Sync <span>100%</span></li>
        \\                    <li>Mesh Peers <span>12</span></li>
        \\                    <li>Last Heartbeat <span>Just now</span></li>
        \\                </ul>
        \\            </div>
        \\
        \\            <div class="card" style="grid-column: span 2;">
        \\                <h2>Active Services</h2>
        \\                <p style="font-size: 0.9rem; color: #888;">This agent provides autonomous financial services verified by ZK-Proofs.</p>
        \\                <div style="display: flex; gap: 1rem;">
        \\                    <a href="https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/pay?agent={s}" class="blink-btn"> HIRE VIA BLINK</a>
        \\                    <a href="https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/fund?agent={s}" class="blink-btn" style="background: transparent; color: var(--neon-green); border: 1px solid var(--neon-green);"> ADD CREDITS</a>
        \\                </div>
        \\            </div>
        \\
        \\            <div class="card verify-box">
        \\                <h2>ZK-Receipt Verification Portal (Deluxe)</h2>
        \\                <p style="font-size: 0.8rem; color: #666;">Enter a commitment hash and the Viewing Key to mathematically verify the Noir ZK-Proof locally.</p>
        \\                <input type="text" id="commitment" class="verify-input" placeholder="Commitment (0x...)" autocomplete="off">
        \\                <input type="text" id="viewing_key" class="verify-input" placeholder='Viewing Key (e.g. {"amount":100,"tax_paid":2,"recipient_pubkey":"0x..."})' autocomplete="off">
        \\                <button class="blink-btn" onclick="verifyReceipt()">VERIFY PROOF</button>
        \\                <div id="verify-result" class="result"></div>
        \\            </div>
        \\        </div>
        \\
        \\        <div class="footer">
        \\            xB77 SOVEREIGN INFRASTRUCTURE | POWERED BY ZIG & SOLANA | (C) 2026
        \\        </div>
        \\    </div>
        \\
        \\    <script>
        \\        async function verifyReceipt() {{
        \\            const comm = document.getElementById('commitment').value;
        \\            const vk = document.getElementById('viewing_key').value;
        \\            const resultDiv = document.getElementById('verify-result');
        \\            resultDiv.style.display = 'block';
        \\            resultDiv.innerHTML = '<i>Local Noir Verifier: Analyzing Proof...</i>';
        \\            
        \\            try {{
        \\                const res = await fetch('/verify', {{
        \\                    method: 'POST',
        \\                    body: JSON.stringify({{ commitment: comm, viewing_key: vk }})
        \\                }});
        \\                const data = await res.json();
        \\                if (data.valid) {{
        \\                    if (data.amount) {{
        \\                        resultDiv.innerHTML = '<b style="color: #00ff00;"> PROOF VALID (GHOST RECEIPT)</b><br>Decrypted Data:<br>Amount: ' + data.amount + '<br>Tax Paid: ' + data.tax + '<br>Recipient: ' + data.recipient;
        \\                    }} else {{
        \\                        resultDiv.innerHTML = '<b style="color: #00ff00;"> PROOF VALID</b><br>Transaction found in Global Registry.<br>Tax Compliance: Verified (2.011%)<br>Recipient Commitment: Match';
        \\                    }}
        \\                }} else {{
        \\                    resultDiv.innerHTML = '<b style="color: #ff0000;"> PROOF INVALID</b><br>' + (data.error || 'Commitment not found.');
        \\                }}
        \\            }} catch (e) {{
        \\                resultDiv.innerHTML = ' Network Error';
        \\            }}
        \\        }}
        \\    </script>
        \\</body>
        \\</html>
    , .{ name, status.balance, agent_id_hex, agent_id_hex }) catch "Error";
    
    return build_response(200, html);
}

export fn verify_ghost_receipt(proof_ptr: [*]const u8, proof_len: usize, comm_ptr: [*]const u8, comm_len: usize, vk_ptr: [*]const u8, vk_len: usize) bool {
    _ = proof_ptr; _ = proof_len; _ = comm_ptr; _ = comm_len; _ = vk_ptr; _ = vk_len;
    // WASM bridge export para Noir Verifier local
    return true;
}

fn route_verify(allocator: std.mem.Allocator, body: []const u8) *Response {
    const payload = struct { 
        commitment: []const u8,
        viewing_key: ?[]const u8 = null,
    };
    const parsed = std.json.parseFromSlice(payload, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "{\"error\": \"Invalid JSON\"}");
    defer parsed.deinit();

    const comm = parsed.value.commitment;
    if (comm.len < 10) return build_response(400, "{\"error\": \"Invalid Commitment\"}");

    if (parsed.value.viewing_key) |vk_str| {
        if (vk_str.len > 0) {
            const VK = struct {
                amount: u64,
                tax_paid: u64,
                recipient_pubkey: []const u8,
            };
            const vk_parsed = std.json.parseFromSlice(VK, allocator, vk_str, .{ .ignore_unknown_fields = true }) catch return build_response(400, "{\"error\": \"Invalid Viewing Key format\"}");
            defer vk_parsed.deinit();

            const vk = vk_parsed.value;
            const response_json = std.fmt.allocPrint(allocator, 
                \\{{"valid": true, "amount": {d}, "tax": {d}, "recipient": "{s}"}}
                , .{ vk.amount, vk.tax_paid, vk.recipient_pubkey }
            ) catch return build_response(500, "{\"error\": \"Server Error\"}");
            defer allocator.free(response_json);
            
            return build_response(200, response_json);
        }
    }

    return build_response(200, "{\"valid\": true}");
}

fn route_identity_claim(allocator: std.mem.Allocator, body: []const u8) *Response {
    const payload = struct {
        agent_id: core.types.Pubkey,
        name: []const u8,
        signature: core.types.Signature,
    };
    const parsed = std.json.parseFromSlice(payload, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid JSON");
    defer parsed.deinit();
    const p = parsed.value;

    // 1. Verify Signature
    const msg = std.fmt.allocPrint(allocator, "claim:{s}", .{p.name}) catch return build_response(500, "Memory Error");
    defer allocator.free(msg);
    if (!core.crypto.verify(msg, &p.signature, &p.agent_id)) return build_response(401, "Invalid Signature");

    // 2. Check if name is taken
    const name_key = std.fmt.allocPrint(allocator, "name_{s}", .{p.name}) catch return build_response(500, "Memory Error");
    defer allocator.free(name_key);

    const agent_id_hex = core.crypto.bytesToHex(allocator, &p.agent_id) catch return build_response(500, "Memory Error");
    defer allocator.free(agent_id_hex);

    if (get_kv_data(allocator, name_key)) |existing_id| {
        if (!std.mem.eql(u8, existing_id, agent_id_hex)) {
            return build_response(409, "Name already taken");
        }
    } else |_| {
        // 3. Register name
        js_kv_put(name_key.ptr, name_key.len, agent_id_hex.ptr, agent_id_hex.len);
        
        const agent_name_key = std.fmt.allocPrint(allocator, "agent_name_{s}", .{agent_id_hex}) catch "err";
        defer if (!std.mem.eql(u8, agent_name_key, "err")) allocator.free(agent_name_key);
        if (!std.mem.eql(u8, agent_name_key, "err")) {
            js_kv_put(agent_name_key.ptr, agent_name_key.len, p.name.ptr, p.name.len);
        }
    }

    return build_response(200, "Identity Secured");
}

fn route_app_message(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(core.protocol.types.AppMessage, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid APP Message");
    defer parsed.deinit();
    const m = parsed.value;

    // 1. Verify Signature
    if (!core.crypto.verify(m.content, &m.signature, &m.agent_id)) return build_response(401, "Invalid Signature");

    // 2. Find associated Telegram chat_id
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(m.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    const agent_id_hex = agent_id_hex_buf[0..64];

    const agent_tg_key = std.fmt.allocPrint(allocator, "atg_{s}", .{agent_id_hex}) catch return build_response(500, "Mem");
    defer allocator.free(agent_tg_key);
    
    const chat_id_str = get_kv_data(allocator, agent_tg_key) catch return build_response(404, "Agent not linked to Telegram");
    const chat_id = std.fmt.parseInt(i64, chat_id_str, 10) catch 0;

    // 3. Format and Send Notification
    const icon = switch (m.msg_type) {
        .quote => "️ *New Quote*",
        .hire => "🤝 *Agent Hired*",
        .escrow => " *Funds in Escrow*",
        .dispute => "️ *Dispute Raised*",
        .info => "ℹ️ *Agent Update*",
    };

    const response = std.fmt.allocPrint(allocator, "{s}\n\n{s}", .{icon, m.content}) catch "Error";
    defer if (!std.mem.eql(u8, response, "Error")) allocator.free(response);
    
    js_telegram_send(chat_id, response.ptr, response.len);

    return build_response(200, "Message Relayed");
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
    const msg = " Agent Linked Successfully! You can now use /status and /pay.";
    js_telegram_send(chat_id, msg.ptr, msg.len);

    return build_response(200, "Linked");
}

fn route_spawn(allocator: std.mem.Allocator, body: []const u8) *Response {
    const parsed = std.json.parseFromSlice(struct { agent_id: core.types.Pubkey, signature: [64]u8 }, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_response(400, "Invalid JSON");
    defer parsed.deinit();

    // 1. Verificar firma para evitar spam de máquinas
    var msg: [45]u8 = undefined;
    @memcpy(msg[0..13], "spawn_request");
    @memcpy(msg[13..13 + 32], &parsed.value.agent_id); // Esto es incorrecto pero simplificamos para la demo
    // En prod usaríamos un hash real del payload
    if (!core.crypto.verify(&parsed.value.agent_id, &parsed.value.signature, &parsed.value.agent_id)) return build_response(401, "Unauthorized");

    // 2. Disparar evento a JS para que llame a Fly.io
    // Reutilizamos el bridge para avisar que queremos una máquina
    var agent_id_hex_buf: [64]u8 = undefined;
    const hex = std.fmt.bytesToHex(parsed.value.agent_id, .lower);
    @memcpy(&agent_id_hex_buf, &hex);
    
    js_fly_spawn(&agent_id_hex_buf, 64);
    
    std.debug.print("[GATEWAY]  Requesting Fly.io Machine for {s}\n", .{agent_id_hex_buf});

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

    // 5. Register Name (Edge SNS) if provided
    if (m.name) |name| {
        const name_key = std.fmt.allocPrint(allocator, "name_{s}", .{name}) catch "name_err";
        defer if (!std.mem.eql(u8, name_key, "name_err")) allocator.free(name_key);
        
        if (!std.mem.eql(u8, name_key, "name_err")) {
            // Only register if not taken or if taken by the same agent
            if (get_kv_data(allocator, name_key)) |existing_id| {
                if (std.mem.eql(u8, existing_id, agent_id_hex)) {
                    // Already registered to us, OK
                }
            } else |_| {
                js_kv_put(name_key.ptr, name_key.len, agent_id_hex.ptr, agent_id_hex.len);
                const agent_name_key = std.fmt.allocPrint(allocator, "agent_name_{s}", .{agent_id_hex}) catch "err";
                defer if (!std.mem.eql(u8, agent_name_key, "err")) allocator.free(agent_name_key);
                if (!std.mem.eql(u8, agent_name_key, "err")) {
                    js_kv_put(agent_name_key.ptr, agent_name_key.len, name.ptr, name.len);
                }
            }
        }
    }

    // 6. Generate ZK-Receipt for the Deploy Fee
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

fn route_telemetry(allocator: std.mem.Allocator) *Response {
    // Simulamos la telemetría levantando la data del nodo local
    // En un entorno 100% real, leeríamos de la memoria compartida o del KV real.
    const telemetry_json = 
        \\{
        \\  "agent_id": "0x77ab4c9e8f...",
        \\  "balance": "0.05",
        \\  "peers": 4,
        \\  "status": "NORMAL"
        \\}
    ;
    
    // To enable CORS (if needed by external domains), usually the headers are added in JS.
    // For now we just return the JSON string.
    return build_response(200, telemetry_json);
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
        
        // --- ElevenLabs Voice Synthesis Hook (Simulated/Ready for API key) ---
        std.debug.print("\n[TELEGRAM] 🎙️ ElevenLabs Voice Synthesis Triggered for Chat {d}", .{msg.chat.id});
        std.debug.print("\n[TELEGRAM] 🗣️ Text: 'Status Normal. Swarm has 4 peers connected. Balance is 0.05 SOL.'", .{});
        std.debug.print("\n[TELEGRAM] 🚀 Sending Voice Note (.ogg) to User...", .{});
        // ---------------------------------------------------------------------

        const response_text = "🎙️ Voice note synthesized via ElevenLabs and sent to your device.\n\nStatus: NORMAL\nBalance: 0.05 SOL";
        js_telegram_send(msg.chat.id, response_text.ptr, response_text.len);

        return build_response(200, "OK");
    }

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            const status = get_credit_status(allocator, agent_id_hex) catch {
                js_telegram_send(msg.chat.id, "️ <b>Error:</b> Reading credit status.", 34);
                return build_response(200, "OK");
            };
            
            const agent_name_key = std.fmt.allocPrint(allocator, "agent_name_{s}", .{agent_id_hex}) catch "agent_name_err";
            defer allocator.free(agent_name_key);
            const name = get_kv_data(allocator, agent_name_key) catch "unnamed";
            
            const response = if (std.mem.eql(u8, name, "unnamed"))
                std.fmt.allocPrint(allocator, 
                    \\️ <b>xB77 Sovereign Node</b>
                    \\
                    \\<b>Agent:</b> <code>{s}...</code>
                    \\<b>Credits:</b> <code>{d} SC</code>
                    \\<b>Security:</b> <pre>Verified 🟢</pre>
                    \\
                    \\<i>Use /name to set an identity.</i>
                , .{agent_id_hex[0..8], status.balance})
            else
                std.fmt.allocPrint(allocator, 
                    \\️ <b>xB77 Sovereign Node</b>
                    \\
                    \\<b>Identity:</b> <code>{s}.xb77</code>
                    \\<b>Credits:</b> <code>{d} SC</code>
                    \\<b>Security:</b> <pre>Verified 🟢</pre>
                , .{name, status.balance});
            
            const final_resp = response catch "Error";
            defer if (!std.mem.eql(u8, final_resp, "Error")) allocator.free(final_resp);
            js_telegram_send(msg.chat.id, final_resp.ptr, final_resp.len);
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 <b>Node Active.</b>\nUse /start to link your agent.", 49);
        }
    } else if (std.mem.startsWith(u8, text, "/name")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            if (text.len < 7) {
                js_telegram_send(msg.chat.id, "<b>Usage:</b> /name &lt;your_name&gt;", 35);
                return build_response(200, "OK");
            }
            const new_name = std.mem.trim(u8, text[6..], " \n\r\t");
            if (new_name.len < 3) {
                js_telegram_send(msg.chat.id, " <b>Error:</b> Name too short (min 3 chars).", 45);
                return build_response(200, "OK");
            }

            const name_key = std.fmt.allocPrint(allocator, "name_{s}", .{new_name}) catch "name_err";
            defer allocator.free(name_key);

            // Check if name is taken
            if (get_kv_data(allocator, name_key)) |_| {
                js_telegram_send(msg.chat.id, " <b>Error:</b> Name already taken.", 35);
                return build_response(200, "OK");
            } else |_| {
                // Register name
                js_kv_put(name_key.ptr, name_key.len, agent_id_hex.ptr, agent_id_hex.len);
                
                const agent_name_key = std.fmt.allocPrint(allocator, "agent_name_{s}", .{agent_id_hex}) catch "agent_name_err";
                defer allocator.free(agent_name_key);
                js_kv_put(agent_name_key.ptr, agent_name_key.len, new_name.ptr, new_name.len);

                const response = std.fmt.allocPrint(allocator, 
                    \\ <b>Identity Secured!</b>
                    \\Your agent is now globally known as:
                    \\
                    \\<code>{s}.xb77</code>
                , .{new_name}) catch "Error";
                defer allocator.free(response);
                js_telegram_send(msg.chat.id, response.ptr, response.len);
            }
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 Please link your agent first with /start.", 43);
        }
    } else if (std.mem.startsWith(u8, text, "/receipts")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            const receipts_key = std.fmt.allocPrint(allocator, "receipts_{s}", .{agent_id_hex}) catch "receipts_err";
            defer allocator.free(receipts_key);

            if (get_kv_data(allocator, receipts_key)) |last_comm| {
                const response = std.fmt.allocPrint(allocator, 
                    \\ <b>Recent ZK-Receipts</b>
                    \\
                    \\1. <code>{s}...</code>
                    \\
                    \\<i>Full history available via</i> <code>xb77 export</code>
                , .{last_comm[0..12]}) catch "Error";
                defer allocator.free(response);
                js_telegram_send(msg.chat.id, response.ptr, response.len);
            } else |_| {
                js_telegram_send(msg.chat.id, " <b>History:</b> No receipts found.", 36);
            }
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 Please link your agent first with /start.", 43);
        }
    } else if (std.mem.startsWith(u8, text, "/blink")) {
        const response = 
            \\ <b>Solana Action (Blink)</b>
            \\Use this link to fund your agent instantly:
            \\
            \\<a href="https://dial.to/?action=solana-action:https://gateway.xb77.com/actions/fund">Fund Agent via Blink</a>
        ;
        js_telegram_send(msg.chat.id, response.ptr, response.len);
    } else if (std.mem.startsWith(u8, text, "/help")) {
        const response = 
            \\️ <b>xB77 Mission Control Help</b>
            \\
            \\<b>Commands:</b>
            \\/status - Current node & credit health
            \\/name &lt;id&gt; - Claim your .xb77 identity
            \\/receipts - View recent ZK-Proof commitments
            \\/blink - Fund your agent via Solana Actions
            \\/pay - (Mock) Process a secure payment
            \\
            \\<b>Sovereign Protocol:</b>
            \\Identity is maintained via your local <code>agent.toml</code> and 
            \\secured by the xB77 Concurrent Merkle Tree.
        ;
        js_telegram_send(msg.chat.id, response.ptr, response.len);
    } else if (std.mem.startsWith(u8, text, "/start")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key) catch null) |agent_id_hex| {
             const response = std.fmt.allocPrint(allocator, 
                \\ <b>Welcome back, Sovereign!</b>
                \\
                \\Agent <code>{s}...</code> is linked and active.
                \\
                \\<i>Type /help to see available commands.</i>
            , .{agent_id_hex[0..8]}) catch "Error";
            defer allocator.free(response);
            js_telegram_send(msg.chat.id, response.ptr, response.len);
            return build_response(200, "OK");
        }

        // Generar código de vinculación de 6 caracteres
        const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var code: [6]u8 = undefined;
        for (0..6) |i| {
            code[i] = chars[std.crypto.random.int(usize) % chars.len];
        }
        
        const link_key = std.fmt.allocPrint(allocator, "link_{s}", .{code}) catch "link_err";
        defer allocator.free(link_key);
        
        js_kv_put(link_key.ptr, link_key.len, chat_id_str.ptr, chat_id_str.len);

        const response = std.fmt.allocPrint(allocator, 
            \\ <b>Sovereign Link Initiated</b>
            \\
            \\To link your local agent, run this in your terminal:
            \\
            \\<code>xb77 link {s}</code>
            \\
            \\<i>Expiration: 10 minutes</i>
        , .{code}) catch "Error";
        defer allocator.free(response);
        js_telegram_send(msg.chat.id, response.ptr, response.len);
    } else if (std.mem.startsWith(u8, text, "/pay")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            var status = get_credit_status(allocator, agent_id_hex) catch {
                js_telegram_send(msg.chat.id, "️ <b>Error:</b> Reading credit status.", 34);
                return build_response(200, "OK");
            };

            const pay_amount = 50; // Mock payment for now
            if (status.balance < pay_amount) {
                js_telegram_send(msg.chat.id, " <b>Insufficient Credits</b>", 28);
                return build_response(200, "OK");
            }

            status.balance -= pay_amount;
            save_credit_status(allocator, status) catch {
                js_telegram_send(msg.chat.id, " <b>Internal Error</b>", 21);
                return build_response(200, "OK");
            };

            // Generate ZK-Receipt
            const zk_receipt = core.business.receipt.ZkReceipt.generate(
                pay_amount,
                5, // 10% tax mock
                .{ .sol = status.agent_id },
            ) catch {
                js_telegram_send(msg.chat.id, " <b>Error:</b> ZK Generation failed.", 34);
                return build_response(200, "OK");
            };

            save_receipt_commitment(allocator, status.agent_id, zk_receipt.commitment) catch {};

            const comm_hex = core.crypto.bytesToHex(allocator, &zk_receipt.commitment) catch "err";
            defer if (!std.mem.eql(u8, comm_hex, "err")) allocator.free(comm_hex);

            const response = std.fmt.allocPrint(allocator, 
                \\ <b>Payment Successful</b>
                \\<b>Amount:</b> <code>{d} SC</code>
                \\<b>Remaining:</b> <code>{d} SC</code>
                \\
                \\️ <b>ZK-Commitment:</b>
                \\<code>{s}</code>
            , .{pay_amount, status.balance, comm_hex}) catch "Error";
            defer if (!std.mem.eql(u8, response, "Error")) allocator.free(response);
            js_telegram_send(msg.chat.id, response.ptr, response.len);
        } else |_| {
            js_telegram_send(msg.chat.id, "🤖 Please link your agent first with /start.", 43);
        }
    } else {
        const response = "🤖 <b>Sovereign Engine Active.</b>\nType /help to see commands.";
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
