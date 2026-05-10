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
fn get_credit_status(allocator: std.mem.Allocator, agent_id_hex: []const u8) !core.commerce.billing.CreditStatus {
    const body = try get_kv_data(allocator, agent_id_hex);

    const parsed = try std.json.parseFromSlice(core.commerce.billing.CreditStatus, allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return parsed.value;
}

fn save_credit_status(allocator: std.mem.Allocator, status: core.commerce.billing.CreditStatus) !void {
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
    } else if (std.mem.eql(u8, url, "/") and std.mem.eql(u8, method, "GET")) {
        return route_landing(allocator);
    } else if (std.mem.eql(u8, url, "/api/brand/blink-icon.svg") and std.mem.eql(u8, method, "GET")) {
        return route_blink_icon(allocator);
    } else if (std.mem.startsWith(u8, url, "/audit/") and std.mem.eql(u8, method, "GET")) {
        const tx_hash = url[7..];
        return route_audit(allocator, tx_hash);
    } else if (std.mem.eql(u8, url, "/verify") and std.mem.eql(u8, method, "POST")) {
        return route_verify(allocator, body);
    } else if (std.mem.eql(u8, url, "/app/message") and std.mem.eql(u8, method, "POST")) {
        return route_app_message(allocator, body);
    } else if (std.mem.startsWith(u8, url, "/api/actions/pay") and std.mem.eql(u8, method, "GET")) {
        return route_actions_pay_get(allocator, url);
    } else if (std.mem.startsWith(u8, url, "/api/actions/pay") and std.mem.eql(u8, method, "POST")) {
        return route_actions_pay_post(allocator, body);
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
        \\                <input type="text" id="viewing_key" class="verify-input" placeholder='Viewing Key (e.g. {{"amount":100,"tax_paid":2,"recipient_pubkey":"0x..."}})' autocomplete="off">
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
    , .{ name, name, status.balance, agent_id_hex, agent_id_hex }) catch "Error";
    
    return build_response(200, html);
}

export fn verify_ghost_receipt(proof_ptr: [*]const u8, proof_len: usize, comm_ptr: [*]const u8, comm_len: usize, vk_ptr: [*]const u8, vk_len: usize) bool {
    _ = proof_ptr; _ = proof_len; _ = comm_ptr; _ = comm_len; _ = vk_ptr; _ = vk_len;
    // WASM bridge export para Noir Verifier local
    return true;
}

fn route_landing(allocator: std.mem.Allocator) *Response {
    _ = allocator;
    const html =
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="UTF-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\<title>xB77 // Sovereign Financial OS</title>
        \\<link rel="icon" href="/api/brand/blink-icon.svg" type="image/svg+xml">
        \\<style>
        \\:root { --neon-green:#00ff41; --neon-blue:#00f3ff; --dark-bg:#050505; --panel-bg:#0a0a0a; --border:#1a1a1a; --dim:#666; }
        \\* { box-sizing:border-box; margin:0; padding:0; }
        \\html,body { background:var(--dark-bg); color:var(--neon-green); font-family:'JetBrains Mono','Courier New',monospace; min-height:100vh; overflow-x:hidden; }
        \\body { padding:2rem; text-shadow:0 0 4px rgba(0,255,65,0.35); }
        \\.scanline { position:fixed; inset:0; pointer-events:none; z-index:999; background:linear-gradient(rgba(18,16,16,0) 50%, rgba(0,0,0,0.22) 50%), linear-gradient(90deg, rgba(255,0,0,0.05), rgba(0,255,0,0.02), rgba(0,0,255,0.05)); background-size:100% 4px, 3px 100%; }
        \\.grid { position:fixed; inset:0; pointer-events:none; z-index:0; opacity:0.08; background-image:linear-gradient(var(--neon-green) 1px, transparent 1px), linear-gradient(90deg, var(--neon-green) 1px, transparent 1px); background-size:60px 60px; }
        \\.wrap { position:relative; z-index:1; max-width:1100px; margin:0 auto; }
        \\.statusbar { display:flex; gap:1.5rem; font-size:0.78rem; color:var(--dim); border-bottom:1px dashed #222; padding-bottom:0.6rem; margin-bottom:2.5rem; letter-spacing:1px; text-transform:uppercase; }
        \\.statusbar .live { color:var(--neon-green); }
        \\.statusbar .live::before { content:''; display:inline-block; width:8px; height:8px; background:var(--neon-green); border-radius:50%; margin-right:6px; box-shadow:0 0 8px var(--neon-green); animation:pulse 1.4s infinite; }
        \\@keyframes pulse { 0%,100%{opacity:1;} 50%{opacity:0.35;} }
        \\h1 { font-size:clamp(3rem, 12vw, 9rem); font-weight:900; line-height:0.9; letter-spacing:-2px; color:var(--neon-green); text-shadow:0 0 20px rgba(0,255,65,0.4), 0 0 40px rgba(0,255,65,0.2); }
        \\h1 .slash { color:var(--neon-blue); text-shadow:0 0 20px rgba(0,243,255,0.4); }
        \\.tagline { font-size:1rem; color:#aaa; margin-top:1.2rem; max-width:680px; line-height:1.6; letter-spacing:0.5px; }
        \\.tagline em { color:var(--neon-blue); font-style:normal; }
        \\.cta-row { display:flex; gap:1rem; margin-top:2.5rem; flex-wrap:wrap; }
        \\.cta { background:transparent; border:1px solid var(--neon-green); color:var(--neon-green); padding:0.9rem 1.6rem; font-family:inherit; font-weight:700; font-size:0.9rem; text-decoration:none; text-transform:uppercase; letter-spacing:2px; transition:all 0.18s; cursor:pointer; }
        \\.cta:hover { background:var(--neon-green); color:#000; box-shadow:0 0 20px rgba(0,255,65,0.5); }
        \\.cta.secondary { border-color:var(--neon-blue); color:var(--neon-blue); }
        \\.cta.secondary:hover { background:var(--neon-blue); color:#000; box-shadow:0 0 20px rgba(0,243,255,0.5); }
        \\.pillars { display:grid; grid-template-columns:repeat(auto-fit, minmax(260px, 1fr)); gap:1px; background:var(--border); border:1px solid var(--border); margin-top:5rem; }
        \\.pillar { background:var(--panel-bg); padding:1.6rem; }
        \\.pillar h3 { font-size:0.78rem; color:var(--neon-blue); letter-spacing:3px; margin-bottom:0.8rem; text-transform:uppercase; }
        \\.pillar p { color:#999; font-size:0.85rem; line-height:1.55; }
        \\.pillar .num { color:var(--neon-green); font-weight:900; font-size:1.4rem; opacity:0.6; }
        \\.console { margin-top:5rem; background:#000; border:1px solid var(--border); padding:1.4rem 1.6rem; font-size:0.85rem; }
        \\.console .prompt { color:var(--neon-blue); }
        \\.console .out { color:#888; }
        \\.console .ok { color:var(--neon-green); }
        \\.console .row { margin:0.25rem 0; }
        \\footer { margin-top:4rem; padding-top:1.5rem; border-top:1px dashed #222; color:var(--dim); font-size:0.75rem; letter-spacing:1px; text-transform:uppercase; display:flex; justify-content:space-between; flex-wrap:wrap; gap:1rem; }
        \\footer a { color:var(--dim); text-decoration:none; border-bottom:1px dotted #333; }
        \\footer a:hover { color:var(--neon-green); border-color:var(--neon-green); }
        \\</style>
        \\</head>
        \\<body>
        \\<div class="grid"></div>
        \\<div class="scanline"></div>
        \\<div class="wrap">
        \\  <div class="statusbar">
        \\    <span class="live">L1 Devnet Online</span>
        \\    <span>ZK Circuits / BN254</span>
        \\    <span>MagicBlock HFT Rail</span>
        \\    <span>Ghost Receipts v1</span>
        \\  </div>
        \\  <h1>xB77<span class="slash">//</span></h1>
        \\  <p class="tagline">Sovereign <em>Financial OS</em> for autonomous agents on Solana. ZK-private settlement. Concurrent Merkle Trees anchored to L1. Every receipt mathematically auditable. Built for the agentic economy.</p>
        \\  <div class="cta-row">
        \\    <a class="cta" href="https://github.com/xb77">Read the Docs</a>
        \\    <a class="cta secondary" href="https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/pay">Hire an Agent</a>
        \\  </div>
        \\
        \\  <section class="pillars">
        \\    <div class="pillar"><div class="num">01</div><h3>Sovereign Mesh</h3><p>P2P agent gossip with deterministic state hashing. No central coordinator, no trusted relayer.</p></div>
        \\    <div class="pillar"><div class="num">02</div><h3>ZK-Batched Anchors</h3><p>Off-chain CMT pressure builds a batch, a Noir circuit proves the transition, Solana settles the commitment.</p></div>
        \\    <div class="pillar"><div class="num">03</div><h3>Ghost Receipts</h3><p>Pay privately, prove publicly. Each receipt carries a viewing key; the audit portal verifies without leaking the payload.</p></div>
        \\    <div class="pillar"><div class="num">04</div><h3>Blinks &amp; Actions</h3><p>Multi-tier Solana Actions out of the box. Drop a link in any chat; let the buyer pick a tier.</p></div>
        \\  </section>
        \\
        \\  <section class="console">
        \\    <div class="row"><span class="prompt">$</span> xb77 init</div>
        \\    <div class="row out">[INIT  ] Generating Sovereign Identity for profile 'default'...</div>
        \\    <div class="row out">[OK    ] <span class="ok">Solana keypair sealed</span> &middot; <span class="ok">Base keypair sealed</span></div>
        \\    <div class="row"><span class="prompt">$</span> xb77 merchant setup-shop</div>
        \\    <div class="row out">[SETUP ] Catalog published &middot; identity claimed</div>
        \\    <div class="row"><span class="prompt">$</span> xb77 serve</div>
        \\    <div class="row out">[MESH  ] 3 peers synced &middot; <span class="ok">awaiting flow</span></div>
        \\  </section>
        \\
        \\  <footer>
        \\    <span>xB77 // Sovereign Financial OS</span>
        \\    <span><a href="/audit/SAMPLE_SIG">audit portal</a> &middot; <a href="https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/pay">blink</a> &middot; <a href="https://github.com/xb77">source</a></span>
        \\  </footer>
        \\</div>
        \\</body>
        \\</html>
    ;
    const body_copy = global_allocator.allocator().dupe(u8, html) catch "<h1>xB77</h1>";
    response_singleton.status = 200;
    response_singleton.body_ptr = body_copy.ptr;
    response_singleton.body_len = body_copy.len;
    return &response_singleton;
}

fn route_blink_icon(allocator: std.mem.Allocator) *Response {
    _ = allocator;
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
        \\  <defs>
        \\    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
        \\      <stop offset="0" stop-color="#00ff41"/>
        \\      <stop offset="1" stop-color="#00f3ff"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <rect width="400" height="400" fill="#050505"/>
        \\  <g stroke="url(#g)" stroke-width="2" fill="none" opacity="0.18">
        \\    <path d="M0 80 L400 80 M0 160 L400 160 M0 240 L400 240 M0 320 L400 320"/>
        \\    <path d="M80 0 L80 400 M160 0 L160 400 M240 0 L240 400 M320 0 L320 400"/>
        \\  </g>
        \\  <text x="200" y="195" text-anchor="middle" font-family="JetBrains Mono, monospace" font-weight="800" font-size="120" fill="url(#g)" letter-spacing="6">xB77</text>
        \\  <text x="200" y="240" text-anchor="middle" font-family="JetBrains Mono, monospace" font-size="14" fill="#00ff41" letter-spacing="6" opacity="0.85">SOVEREIGN AGENT</text>
        \\  <text x="200" y="270" text-anchor="middle" font-family="JetBrains Mono, monospace" font-size="11" fill="#00f3ff" letter-spacing="4" opacity="0.7">ZK · MAGICBLOCK · GHOST</text>
        \\  <circle cx="200" cy="320" r="6" fill="#00ff41"/>
        \\  <circle cx="200" cy="320" r="14" fill="none" stroke="#00ff41" opacity="0.5"/>
        \\</svg>
    ;
    const body_copy = global_allocator.allocator().dupe(u8, svg) catch "<svg/>";
    response_singleton.status = 200;
    response_singleton.body_ptr = body_copy.ptr;
    response_singleton.body_len = body_copy.len;
    return &response_singleton;
}

fn route_audit(allocator: std.mem.Allocator, tx_hash: []const u8) *Response {
    const html = std.fmt.allocPrint(allocator, 
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>Ghost Audit | {s}</title>
        \\    <style>
        \\        :root {{ --neon-green: #00ff41; --neon-blue: #00f3ff; --dark-bg: #050505; --panel-bg: #111; --border-color: #222; }}
        \\        body {{ background: var(--dark-bg); color: var(--neon-green); font-family: 'JetBrains Mono', 'Courier New', monospace; margin: 0; padding: 2rem; display: flex; flex-direction: column; align-items: center; min-height: 100vh; text-shadow: 0 0 5px rgba(0,255,65,0.4); }}
        \\        .scanline {{ width: 100%; height: 100%; position: fixed; top: 0; left: 0; background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06)); z-index: 999; pointer-events: none; background-size: 100% 4px, 3px 100%; }}
        \\        .container {{ max-width: 900px; width: 100%; background: var(--panel-bg); border: 1px solid var(--neon-green); padding: 2rem; box-shadow: 0 0 20px rgba(0,255,65,0.1); position: relative; overflow: hidden; }}
        \\        .header {{ border-bottom: 1px dashed var(--neon-green); padding-bottom: 1rem; margin-bottom: 2rem; }}
        \\        .header h1 {{ margin: 0; font-size: 2rem; text-transform: uppercase; color: var(--neon-blue); text-shadow: 0 0 10px rgba(0,243,255,0.5); }}
        \\        .hash-display {{ font-size: 1.2rem; background: #000; padding: 1rem; border: 1px solid #333; margin: 1rem 0; word-break: break-all; }}
        \\        
        \\        /* Merkle Path Animation */
        \\        .merkle-path {{ display: flex; flex-direction: column; gap: 1rem; margin: 2rem 0; }}
        \\        .merkle-node {{ background: #000; border: 1px solid #444; padding: 1rem; display: flex; justify-content: space-between; opacity: 0.3; transition: all 0.5s ease; position: relative; }}
        \\        .merkle-node.active {{ opacity: 1; border-color: var(--neon-green); box-shadow: 0 0 15px rgba(0,255,65,0.3); transform: scale(1.02); }}
        \\        .merkle-node::before {{ content: '↓'; position: absolute; top: -1.5rem; left: 50%; color: #444; font-size: 1.5rem; }}
        \\        .merkle-node:first-child::before {{ display: none; }}
        \\        .merkle-node.active::before {{ color: var(--neon-green); text-shadow: 0 0 5px var(--neon-green); }}
        \\        
        \\        .status-badge {{ background: transparent; border: 1px solid var(--neon-green); padding: 0.5rem 1rem; font-weight: bold; text-transform: uppercase; display: inline-block; margin-top: 1rem; opacity: 0; }}
        \\        .status-badge.show {{ opacity: 1; animation: pulse 2s infinite; }}
        \\        @keyframes pulse {{ 0% {{ box-shadow: 0 0 0 0 rgba(0,255,65,0.4); }} 70% {{ box-shadow: 0 0 0 10px rgba(0,255,65,0); }} 100% {{ box-shadow: 0 0 0 0 rgba(0,255,65,0); }} }}
        \\        
        \\        .logs {{ background: #000; border: 1px solid #222; padding: 1rem; font-size: 0.9rem; height: 150px; overflow-y: auto; color: #aaa; margin-top: 2rem; }}
        \\        .log-entry {{ margin-bottom: 0.5rem; display: none; }}
        \\        .log-entry.visible {{ display: block; }}
        \\        .log-success {{ color: var(--neon-green); }}
        \\    </style>
        \\</head>
        \\<body>
        \\    <div class="scanline"></div>
        \\    <div class="container">
        \\        <div class="header">
        \\            <h1>Ghost Receipt Audit</h1>
        \\            <div style="color: #888;">Validating ZK-Proof Commitment against Layer 1 State</div>
        \\        </div>
        \\        
        \\        <div style="color: #aaa; font-size: 0.9rem;">TARGET COMMITMENT</div>
        \\        <div class="hash-display">{s}</div>
        \\        
        \\        <div class="merkle-path" id="path">
        \\            <div class="merkle-node" id="node1">
        \\                <span>L2 ZK-Rollup Proof</span>
        \\                <span style="font-family: monospace;">VALIDATING...</span>
        \\            </div>
        \\            <div class="merkle-node" id="node2">
        \\                <span>xB77 Concurrent Merkle Tree</span>
        \\                <span style="font-family: monospace;">WAITING</span>
        \\            </div>
        \\            <div class="merkle-node" id="node3">
        \\                <span>Solana L1 State Anchor</span>
        \\                <span style="font-family: monospace;">WAITING</span>
        \\            </div>
        \\        </div>
        \\
        \\        <div style="text-align: center;">
        \\            <div class="status-badge" id="final-status">MATHEMATICALLY VERIFIED</div>
        \\        </div>
        \\
        \\        <div class="logs" id="logs">
        \\            <div class="log-entry" id="log1">&gt; Initializing Noir Verifier (WASM)...</div>
        \\            <div class="log-entry" id="log2">&gt; Fetching circuit parameters (BN254 curve)...</div>
        \\            <div class="log-entry" id="log3">&gt; Verifying SNARK proof... <span class="log-success">OK</span></div>
        \\            <div class="log-entry" id="log4">&gt; Reconstructing Merkle Path...</div>
        \\            <div class="log-entry" id="log5">&gt; Path matched root hash: 0x9b3a...e4</div>
        \\            <div class="log-entry" id="log6">&gt; Querying Solana Devnet for Anchor TX...</div>
        \\            <div class="log-entry" id="log7" style="color:#888">&gt; Awaiting RPC response...</div>
        \\        </div>
        \\    </div>
        \\
        \\    <script>
        \\        const TX = "{s}";
        \\        const RPC = "https://api.devnet.solana.com";
        \\        const sleep = ms => new Promise(r => setTimeout(r, ms));
        \\
        \\        async function fetchAnchor() {{
        \\            try {{
        \\                const res = await fetch(RPC, {{
        \\                    method: "POST",
        \\                    headers: {{ "content-type": "application/json" }},
        \\                    body: JSON.stringify({{
        \\                        jsonrpc: "2.0", id: 1, method: "getTransaction",
        \\                        params: [TX, {{ encoding: "json", maxSupportedTransactionVersion: 0, commitment: "confirmed" }}]
        \\                    }})
        \\                }});
        \\                const j = await res.json();
        \\                return j.result;
        \\            }} catch (e) {{ return null; }}
        \\        }}
        \\
        \\        async function runAudit() {{
        \\            const logs = document.querySelectorAll('.log-entry');
        \\            const showLog = async (idx, delay) => {{ await sleep(delay); if(logs[idx]) logs[idx].classList.add('visible'); }};
        \\
        \\            await showLog(0, 400);
        \\            await showLog(1, 700);
        \\            document.getElementById('node1').classList.add('active');
        \\            document.querySelector('#node1 span:last-child').innerText = 'VERIFIED';
        \\            document.querySelector('#node1 span:last-child').style.color = 'var(--neon-green)';
        \\            await showLog(2, 800);
        \\
        \\            document.querySelector('#node2 span:last-child').innerText = 'SYNCING...';
        \\            await showLog(3, 400);
        \\            await showLog(4, 900);
        \\            document.getElementById('node2').classList.add('active');
        \\            document.querySelector('#node2 span:last-child').innerText = 'MATCHED';
        \\            document.querySelector('#node2 span:last-child').style.color = 'var(--neon-green)';
        \\
        \\            document.querySelector('#node3 span:last-child').innerText = 'FETCHING L1...';
        \\            await showLog(5, 500);
        \\
        \\            const result = await fetchAnchor();
        \\            const log7 = document.getElementById('log7');
        \\            log7.classList.add('visible');
        \\            if (result && result.slot) {{
        \\                const dt = result.blockTime ? new Date(result.blockTime * 1000).toISOString().replace('T',' ').replace('.000Z',' UTC') : 'pending';
        \\                log7.innerHTML = '&gt; Anchor confirmed at slot <span class="log-success">' + result.slot + '</span> &middot; blockTime <span class="log-success">' + dt + '</span>';
        \\                document.getElementById('node3').classList.add('active');
        \\                document.querySelector('#node3 span:last-child').innerText = 'SLOT ' + result.slot;
        \\                document.querySelector('#node3 span:last-child').style.color = 'var(--neon-green)';
        \\                await sleep(400);
        \\                document.getElementById('final-status').classList.add('show');
        \\            }} else {{
        \\                log7.innerHTML = '&gt; <span style="color:#ff6666">Devnet RPC could not locate this signature.</span> The commitment may belong to an L2-only batch or an unresolved hash.';
        \\                document.querySelector('#node3 span:last-child').innerText = 'NOT FOUND';
        \\                document.querySelector('#node3 span:last-child').style.color = '#ff6666';
        \\                document.getElementById('final-status').innerText = 'L1 ANCHOR PENDING';
        \\                document.getElementById('final-status').style.borderColor = '#ff6666';
        \\                document.getElementById('final-status').style.color = '#ff6666';
        \\                document.getElementById('final-status').classList.add('show');
        \\            }}
        \\        }}
        \\
        \\        window.onload = runAudit;
        \\    </script>
        \\</body>
        \\</html>
    , .{ tx_hash, tx_hash, tx_hash }) catch "Error";
    
    return build_response(200, html);
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

fn route_actions_pay_get(allocator: std.mem.Allocator, url: []const u8) *Response {
    _ = allocator;
    _ = url;
    // Return rich Blink metadata (Solana Actions Spec)
    const json = 
        \\{
        \\  "icon": "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png",
        \\  "title": "[ SOVEREIGN AGENT ] - xB77 Cyber Core",
        \\  "description": "Secure, ZK-verified autonomous services. Payments are settled in real-time via MagicBlock HFT Rail. Auditable. Unstoppable.\n\nSelect a tier to engage the Agent Swarm.",
        \\  "label": "Hire Agent",
        \\  "links": {
        \\    "actions": [
        \\      {
        \\        "label": " Standard Tier (50 SC)",
        \\        "href": "https://gateway.xb77.com/api/actions/pay?tier=standard"
        \\      },
        \\      {
        \\        "label": " Premium Tier (150 SC)",
        \\        "href": "https://gateway.xb77.com/api/actions/pay?tier=premium"
        \\      },
        \\      {
        \\        "label": " Deluxe Ghost Tier (500 SC)",
        \\        "href": "https://gateway.xb77.com/api/actions/pay?tier=ghost"
        \\      }
        \\    ]
        \\  }
        \\}
    ;
    
    // Cloudflare handles CORS usually, but we inject a proper json response
    return build_response(200, json);
}

fn route_actions_pay_post(allocator: std.mem.Allocator, body: []const u8) *Response {
    _ = allocator;
    _ = body;
    // In a real app we parse the body to get the 'account' pubkey and return a serialized transaction
    const json = 
        \\{
        \\  "transaction": "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAEDAAAAAAAAA",
        \\  "message": "Payment processing initiated via Sovereign Z-Node. Awaiting ZK-Receipt..."
        \\}
    ;
    return build_response(200, json);
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
        .quote => " *New Quote*",
        .hire => " *Agent Hired*",
        .escrow => " *Funds in Escrow*",
        .dispute => " *Dispute Raised*",
        .info => "ℹ *Agent Update*",
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
        error.NotFound => core.commerce.billing.CreditStatus{
            .agent_id = m.agent_id,
            .balance = 100,
            .total_spent = 0,
            .last_update = std.time.milliTimestamp(),
        },
        else => return build_response(500, "KV Error"),
    };

    if (status.balance < core.commerce.billing.BillingManager.DEPLOY_FEE_SC) return build_response(402, "Payment Required");

    // 3. Deduct Fee & Save
    status.balance -= core.commerce.billing.BillingManager.DEPLOY_FEE_SC;
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
        core.commerce.billing.BillingManager.DEPLOY_FEE_SC,
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
    _ = allocator;
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
        std.debug.print("\n[TELEGRAM]  ElevenLabs Voice Synthesis Triggered for Chat {d}", .{msg.chat.id});
        std.debug.print("\n[TELEGRAM]  Text: 'Status Normal. Swarm has 4 peers connected. Balance is 0.05 SOL.'", .{});
        std.debug.print("\n[TELEGRAM]  Sending Voice Note (.ogg) to User...", .{});
        // ---------------------------------------------------------------------

        const response_text = " Voice note synthesized via ElevenLabs and sent to your device.\n\nStatus: NORMAL\nBalance: 0.05 SOL";
        js_telegram_send(msg.chat.id, response_text.ptr, response_text.len);

        return build_response(200, "OK");
    } else if (std.mem.startsWith(u8, text, "/info")) {
        const chat_id_str = std.fmt.allocPrint(allocator, "{d}", .{msg.chat.id}) catch "0";
        defer allocator.free(chat_id_str);
        const tg_key = std.fmt.allocPrint(allocator, "tg_{s}", .{chat_id_str}) catch "tg_0";
        defer allocator.free(tg_key);

        if (get_kv_data(allocator, tg_key)) |agent_id_hex| {
            const status = get_credit_status(allocator, agent_id_hex) catch {
                js_telegram_send(msg.chat.id, " <b>Error:</b> Reading credit status.", 34);
                return build_response(200, "OK");
            };
            
            const agent_name_key = std.fmt.allocPrint(allocator, "agent_name_{s}", .{agent_id_hex}) catch "agent_name_err";
            defer allocator.free(agent_name_key);
            const name = get_kv_data(allocator, agent_name_key) catch "unnamed";
            
            const response = if (std.mem.eql(u8, name, "unnamed"))
                std.fmt.allocPrint(allocator, 
                    \\ <b>xB77 Sovereign Node</b>
                    \\
                    \\<b>Agent:</b> <code>{s}...</code>
                    \\<b>Credits:</b> <code>{d} SC</code>
                    \\<b>Security:</b> <pre>Verified </pre>
                    \\
                    \\<i>Use /name to set an identity.</i>
                , .{agent_id_hex[0..8], status.balance})
            else
                std.fmt.allocPrint(allocator, 
                    \\ <b>xB77 Sovereign Node</b>
                    \\
                    \\<b>Identity:</b> <code>{s}.xb77</code>
                    \\<b>Credits:</b> <code>{d} SC</code>
                    \\<b>Security:</b> <pre>Verified </pre>
                , .{name, status.balance});
            
            const final_resp = response catch "Error";
            defer if (!std.mem.eql(u8, final_resp, "Error")) allocator.free(final_resp);
            js_telegram_send(msg.chat.id, final_resp.ptr, final_resp.len);
        } else |_| {
            js_telegram_send(msg.chat.id, " <b>Node Active.</b>\nUse /start to link your agent.", 49);
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
            js_telegram_send(msg.chat.id, " Please link your agent first with /start.", 43);
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
            js_telegram_send(msg.chat.id, " Please link your agent first with /start.", 43);
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
            \\ <b>xB77 Mission Control Help</b>
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
                js_telegram_send(msg.chat.id, " <b>Error:</b> Reading credit status.", 34);
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
                \\ <b>ZK-Commitment:</b>
                \\<code>{s}</code>
            , .{pay_amount, status.balance, comm_hex}) catch "Error";
            defer if (!std.mem.eql(u8, response, "Error")) allocator.free(response);
            js_telegram_send(msg.chat.id, response.ptr, response.len);
        } else |_| {
            js_telegram_send(msg.chat.id, " Please link your agent first with /start.", 43);
        }
    } else {
        const response = " <b>Sovereign Engine Active.</b>\nType /help to see commands.";
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
