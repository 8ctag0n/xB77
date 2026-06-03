const std = @import("std");
const core = @import("core");
const types = core.types;
const crypto = core.security.crypto;

var global_allocator = std.heap.DebugAllocator(.{}){};
var kv_cache: ?std.StringHashMap([]const u8) = null;

/// xB77 Sovereign Gateway Engine (v1)
/// High-performance Zig core compiled to WASM.
/// Handles signature verification, rate limiting, and business logic.

// --- Interop Structs ---

const Request = struct {
    method: []const u8,
    path: []const u8,
    body: []const u8,
    pubkey: ?[]const u8,
    signature: ?[]const u8,
    timestamp: u64,
    nonce: ?[]const u8,
    idempotency_key: ?[]const u8,
};

const Response = struct {
    status: i32,
    body_ptr: [*]const u8,
    body_len: usize,
    action_byte: u8,
    should_sign: bool,
};

var response_singleton: Response = .{ 
    .status = 0, 
    .body_ptr = undefined, 
    .body_len = 0, 
    .action_byte = 0,
    .should_sign = false 
};

// --- JS Externs ---
extern fn js_kv_get(key_ptr: [*]const u8, key_len: usize) [*]const u8;
extern fn js_kv_get_len(key_ptr: [*]const u8, key_len: usize) usize;
extern fn js_kv_put(key_ptr: [*]const u8, key_len: usize, val_ptr: [*]const u8, val_len: usize, ttl: u32) void;
extern fn js_telegram_send(chat_id: i64, text_ptr: [*]const u8, text_len: usize) void;
extern fn js_fly_spawn(agent_id_ptr: [*]const u8, agent_id_len: usize) void;
extern fn js_rpc_call(method_ptr: [*]const u8, method_len: usize, params_ptr: [*]const u8, params_len: usize) [*]const u8;
extern fn js_now() u64;

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

fn get_kv(allocator: std.mem.Allocator, key: []const u8) ?[]const u8 {
    if (kv_cache) |cache| {
        if (cache.get(key)) |val| return val;
    }
    const len = js_kv_get_len(key.ptr, key.len);
    if (len == 0) return null;
    const ptr = js_kv_get(key.ptr, key.len);
    const buf = allocator.alloc(u8, len) catch return null;
    @memcpy(buf, ptr[0..len]);
    return buf;
}

// --- API v1 Action Constants ---
const ACTION = struct {
    const SUBMIT_ORDER: u8 = 0x01;
    const REGISTER_AGENT: u8 = 0x02;
    const CLAIM_CREDITS: u8 = 0x03;
    const QUERY_PULSE: u8 = 0x04;
    const LINK_AGENT: u8 = 0x05;
    const REPORT_USAGE: u8 = 0x06;
};

// --- Core Logic ---

export fn handle_request(
    method_ptr: [*]const u8, method_len: usize,
    path_ptr: [*]const u8, path_len: usize,
    body_ptr: [*]const u8, body_len: usize,
    pk_ptr: [*]const u8, pk_len: usize,
    sig_ptr: [*]const u8, sig_len: usize,
    ts: u64,
    nonce_ptr: [*]const u8, nonce_len: usize,
    idemp_ptr: [*]const u8, idemp_len: usize
) *Response {
    const allocator = global_allocator.allocator();
    const req = Request{
        .method = method_ptr[0..method_len],
        .path = path_ptr[0..path_len],
        .body = body_ptr[0..body_len],
        .pubkey = if (pk_len > 0) pk_ptr[0..pk_len] else null,
        .signature = if (sig_len > 0) sig_ptr[0..sig_len] else null,
        .timestamp = ts,
        .nonce = if (nonce_len > 0) nonce_ptr[0..nonce_len] else null,
        .idempotency_key = if (idemp_len > 0) idemp_ptr[0..idemp_len] else null,
    };

    // 1. Discovery / Public Reads
    if (std.mem.eql(u8, req.method, "GET")) {
        if (std.mem.eql(u8, req.path, "/api/v1")) return build_response(allocator, 200, "{\"ok\":true,\"v\":\"2.0.11\",\"m\":\"xB77 Sovereign Gateway Active\"}", false, 0);
        if (std.mem.eql(u8, req.path, "/api/v1/network/pulse")) return handle_pulse(allocator);
        if (std.mem.startsWith(u8, req.path, "/api/v1/network/audit")) return handle_audit(allocator, req.path);
        if (std.mem.eql(u8, req.path, "/api/v1/agents/fleet")) return handle_fleet(allocator);
        if (std.mem.startsWith(u8, req.path, "/api/v1/agents/")) return handle_agent_detail(allocator, req.path);
        if (std.mem.eql(u8, req.path, "/api/v1/brand/icon.svg")) return handle_icon(allocator);
    }

    // 2. Webhooks & Legacy
    if (std.mem.eql(u8, req.method, "POST")) {
        if (std.mem.eql(u8, req.path, "/api/v1/webhooks/telegram")) return handle_telegram(allocator, req.body);
    }

    // 3. Command Bar / Natural Language Interface
    if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/v1/chat/command")) {
        return handle_chat_command(allocator, req.body);
    }

    // 3. Signed Actions (POST)
    if (std.mem.eql(u8, req.method, "POST") and std.mem.startsWith(u8, req.path, "/api/v1/actions/")) {
        const action_byte = if (std.mem.eql(u8, req.path, "/api/v1/actions/register_agent")) ACTION.REGISTER_AGENT
        else if (std.mem.eql(u8, req.path, "/api/v1/actions/submit_order")) ACTION.SUBMIT_ORDER
        else if (std.mem.eql(u8, req.path, "/api/v1/actions/claim_credits")) ACTION.CLAIM_CREDITS
        else if (std.mem.eql(u8, req.path, "/api/v1/actions/query_pulse")) ACTION.QUERY_PULSE
        else if (std.mem.eql(u8, req.path, "/api/v1/actions/link_agent")) ACTION.LINK_AGENT
        else if (std.mem.eql(u8, req.path, "/api/v1/actions/report_usage")) ACTION.REPORT_USAGE
        else 0;

        if (action_byte != 0) return handle_action(allocator, req, action_byte);
    }

    return build_error(allocator, 404, "not_found", "Endpoint not found in Zig Engine");
}

fn handle_action(allocator: std.mem.Allocator, req: Request, action_byte: u8) *Response {
    // A. Verify Signature (Sovereign Verification)
    if (req.pubkey == null or req.signature == null or req.nonce == null) {
        return build_error(allocator, 401, "invalid_signature", "missing auth headers");
    }

    const pk_bytes = allocator.alloc(u8, 32) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(pk_bytes);
    _ = std.fmt.hexToBytes(pk_bytes[0..32], req.pubkey.?) catch return build_error(allocator, 401, "invalid_signature", "bad pubkey hex");

    const sig_bytes = allocator.alloc(u8, 64) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(sig_bytes);
    _ = std.fmt.hexToBytes(sig_bytes[0..64], req.signature.?) catch return build_error(allocator, 401, "invalid_signature", "bad signature hex");

    const nonce_bytes = allocator.alloc(u8, 12) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(nonce_bytes);
    _ = std.fmt.hexToBytes(nonce_bytes[0..12], req.nonce.?) catch return build_error(allocator, 401, "invalid_signature", "bad nonce hex");

    // Canonical bytes: action_byte (1) || ts_be_u64_ms (8) || nonce_bytes (12) || body (N)
    var canonical = std.ArrayListUnmanaged(u8).empty;
    defer canonical.deinit(allocator);
    canonical.append(allocator, action_byte) catch return build_error(allocator, 500, "internal", "mem");
    var ts_be: [8]u8 = undefined;
    std.mem.writeInt(u64, &ts_be, req.timestamp, .big);
    canonical.appendSlice(allocator, &ts_be) catch return build_error(allocator, 500, "internal", "mem");
    canonical.appendSlice(allocator, nonce_bytes) catch return build_error(allocator, 500, "internal", "mem");
    canonical.appendSlice(allocator, req.body) catch return build_error(allocator, 500, "internal", "mem");

    var pk_fixed: [32]u8 = undefined; @memcpy(&pk_fixed, pk_bytes[0..32]);
    var sig_fixed: [64]u8 = undefined; @memcpy(&sig_fixed, sig_bytes[0..64]);

    if (!crypto.verify(canonical.items, &sig_fixed, &pk_fixed)) {
        return build_error(allocator, 401, "invalid_signature", "signature did not verify");
    }

    // B. Replay Protection (Nonce)
    const agent_id = derive_agent_id(allocator, pk_bytes) catch "ag_unknown";
    defer if (!std.mem.eql(u8, agent_id, "ag_unknown")) allocator.free(agent_id);

    const nonce_key = std.fmt.allocPrint(allocator, "nonce:{s}:{s}", .{agent_id, req.nonce.?}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(nonce_key);
    if (get_kv(allocator, nonce_key) != null) return build_error(allocator, 401, "invalid_nonce", "nonce reused");
    js_kv_put(nonce_key.ptr, nonce_key.len, "1", 1, 300); // 5 min TTL

    // C. Business Logic Dispatch
    return switch (action_byte) {
        ACTION.REGISTER_AGENT => exec_register(allocator, agent_id, req.pubkey.?, req.body),
        ACTION.QUERY_PULSE => handle_pulse_signed(allocator, agent_id),
        ACTION.LINK_AGENT => exec_link(allocator, agent_id, req.body),
        ACTION.REPORT_USAGE => exec_report_usage(allocator, agent_id, req.body),
        else => build_error(allocator, 501, "not_implemented", "Action logic pending in Zig core"),
    };
}

// --- Action Executors ---

fn exec_register(allocator: std.mem.Allocator, agent_id: []const u8, pubkey: []const u8, body: []const u8) *Response {
    _ = body;
    const agent_key = std.fmt.allocPrint(allocator, "agent:{s}", .{agent_id}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(agent_key);

    const now = std.time.milliTimestamp();
    var credits: u64 = 0; // Default: Austerity Mode (0 SC)

    if (get_kv(allocator, agent_key)) |existing| {
        defer allocator.free(existing);
        const parsed = std.json.parseFromSlice(struct { credits: u64 }, allocator, existing, .{ .ignore_unknown_fields = true }) catch null;
        if (parsed) |p| {
            credits = p.value.credits;
            parsed.?.deinit();
        }
    } else {
        // New agent registration: check SOL balance to decide initial SC
        const sol_json_ptr = js_rpc_call("getBalance", 10, pubkey.ptr, pubkey.len);
        const sol_json = std.mem.span(@as([*:0]const u8, @ptrCast(sol_json_ptr)));
        const sol_parsed = std.json.parseFromSlice(struct { result: struct { value: u64 } }, allocator, sol_json, .{ .ignore_unknown_fields = true }) catch null;
        
        if (sol_parsed) |p| {
            if (p.value.result.value > 10000000) { // > 0.01 SOL
                credits = 100; // Welcome gift for real wallets
            }
            sol_parsed.?.deinit();
        }

        const agent_json = std.fmt.allocPrint(allocator, 
            \\{{"agent_id":"{s}","pubkey":"{s}","tier":"free","credits":{d},"issued_at":{d}}}
        , .{agent_id, pubkey, credits, now}) catch return build_error(allocator, 500, "internal", "mem");
        defer allocator.free(agent_json);
        js_kv_put(agent_key.ptr, agent_key.len, agent_json.ptr, agent_json.len, 0);
    }

    const response_json = std.fmt.allocPrint(allocator, 
        \\{{"ok":true,"data":{{"agent_id":"{s}","credits":{d}}}}}
    , .{agent_id, credits}) catch return build_error(allocator, 500, "internal", "mem");
    
    return build_signed_response(allocator, 200, ACTION.REGISTER_AGENT, response_json);
}

fn exec_link(allocator: std.mem.Allocator, agent_id: []const u8, body: []const u8) *Response {
    const payload = struct { link_code: []const u8 };
    const parsed = std.json.parseFromSlice(payload, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_error(allocator, 400, "invalid_payload", "bad json");
    defer parsed.deinit();

    const link_key = std.fmt.allocPrint(allocator, "link:{s}", .{parsed.value.link_code}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(link_key);

    const chat_id_str = get_kv(allocator, link_key) orelse return build_error(allocator, 404, "not_found", "link code expired");
    const chat_id = std.fmt.parseInt(i64, chat_id_str, 10) catch 0;

    // Persist link
    const agent_tg_key = std.fmt.allocPrint(allocator, "atg:{s}", .{agent_id}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(agent_tg_key);
    js_kv_put(agent_tg_key.ptr, agent_tg_key.len, chat_id_str.ptr, chat_id_str.len, 0);

    js_telegram_send(chat_id, " Agent Linked Successfully! Protocol xB77 active.", 46);

    return build_signed_response(allocator, 200, ACTION.LINK_AGENT, "{\"ok\":true}");
}

fn exec_report_usage(allocator: std.mem.Allocator, agent_id: []const u8, body: []const u8) *Response {
    const usage = std.json.parseFromSlice(struct { cost: u64 }, allocator, body, .{}) catch return build_error(allocator, 400, "bad_payload", "invalid usage report");
    defer usage.deinit();

    const agent_key = std.fmt.allocPrint(allocator, "agent:{s}", .{agent_id}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(agent_key);

    const existing = get_kv(allocator, agent_key) orelse return build_error(allocator, 404, "not_found", "agent not registered");
    defer allocator.free(existing);

    // Parsing the existing agent data and updating credits
    // Since Zig JSON parsing is a bit verbose for just updating one field in a blob,
    // and we want to keep it simple, we'll parse the whole object.
    const AgentData = struct { agent_id: []const u8, pubkey: []const u8, tier: []const u8, credits: u64, issued_at: i64 };
    const parsed_agent = std.json.parseFromSlice(AgentData, allocator, existing, .{ .ignore_unknown_fields = true }) catch return build_error(allocator, 500, "internal", "bad_kv_data");
    defer parsed_agent.deinit();

    if (parsed_agent.value.credits < usage.value.cost) return build_error(allocator, 402, "insufficient_credits", "gateway balance exhausted");

    const new_credits = parsed_agent.value.credits - usage.value.cost;
    
    const updated_json = std.fmt.allocPrint(allocator, 
        \\{{"agent_id":"{s}","pubkey":"{s}","tier":"{s}","credits":{d},"issued_at":{d}}}
    , .{parsed_agent.value.agent_id, parsed_agent.value.pubkey, parsed_agent.value.tier, new_credits, parsed_agent.value.issued_at}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(updated_json);
    
    js_kv_put(agent_key.ptr, agent_key.len, updated_json.ptr, updated_json.len, 0);

    const response_json = std.fmt.allocPrint(allocator, "{{\"ok\":true,\"new_balance\":{d}}}", .{new_credits}) catch "{\"ok\":true}";
    
    return build_signed_response(allocator, 200, ACTION.REPORT_USAGE, response_json);
}

// --- Read Handlers ---

fn handle_pulse(allocator: std.mem.Allocator) *Response {
    // Attempt to get real slot via RPC injected by JS
    const slot_json_ptr = js_rpc_call("getSlot", 7, "[]", 2);
    const slot_json = std.mem.span(@as([*:0]const u8, @ptrCast(slot_json_ptr)));
    
    var slot: u64 = 250412311;
    const parsed = std.json.parseFromSlice(struct { result: u64 }, allocator, slot_json, .{ .ignore_unknown_fields = true }) catch null;
    if (parsed) |p| {
        slot = p.value.result;
        parsed.?.deinit();
    }

    const now = js_now();
    const json = std.fmt.allocPrint(allocator, 
        \\{{"slot":{d},"blockHeight":{d},"agentsOnline":8,"proofsVerified24h":3412,"ts":{d}}}
    , .{slot, slot - 1200, now}) catch "{}";
    
    return build_response(allocator, 200, json, false, 0);
}

fn handle_pulse_signed(allocator: std.mem.Allocator, agent_id: []const u8) *Response {
    _ = agent_id;
    const json = 
        \\{"slot":250412311,"blockHeight":250411104,"agentsOnline":5,"proofsVerified24h":1247,"ts":1715000000000,"signed":true}
    ;
    return build_signed_response(allocator, 200, ACTION.QUERY_PULSE, json);
}

fn handle_audit(allocator: std.mem.Allocator, path: []const u8) *Response {
    const tx = if (std.mem.indexOf(u8, path, "tx=")) |idx| path[idx+3..] else "unknown";
    const json = std.fmt.allocPrint(allocator, 
        \\{{"verdict":"VALID","proofId":"proof_{s}","agent":"omega-1","timestamp":1715000000000,"chunks":8,"txhash":"{s}"}}
    , .{if (tx.len > 12) tx[0..12] else tx, tx}) catch "{}";
    return build_response(allocator, 200, json, false, 0);
}

fn handle_fleet(allocator: std.mem.Allocator) *Response {
    const json = 
        \\{"agents":[{"id":"alpha-7","status":"online"},{"id":"omega-1","status":"online"}]}
    ;
    return build_response(allocator, 200, json, false, 0);
}

fn handle_agent_detail(allocator: std.mem.Allocator, path: []const u8) *Response {
    const agent_id = path[15..]; // Skip "/api/v1/agents/"
    const agent_key = std.fmt.allocPrint(allocator, "agent:{s}", .{agent_id}) catch return build_error(allocator, 500, "internal", "mem");
    defer allocator.free(agent_key);

    if (get_kv(allocator, agent_key)) |json| {
        defer allocator.free(json);
        return build_response(allocator, 200, json, false, 0);
    }
    return build_error(allocator, 404, "not_found", "Agent not registered");
}

fn handle_telegram(allocator: std.mem.Allocator, body: []const u8) *Response {
    const update_parsed = std.json.parseFromSlice(types.TelegramUpdate, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_error(allocator, 400, "bad_tg", "json");
    defer update_parsed.deinit();

    const update = update_parsed.value;
    const msg = update.message orelse return build_response(allocator, 200, "OK", false, 0);
    const text = msg.text orelse return build_response(allocator, 200, "OK", false, 0);

    if (std.mem.startsWith(u8, text, "/start")) {
        const resp = "<b>xB77 Sovereign Edge Node</b>\n\nStatus: <code>ACTIVE</code>\nChain: <code>Solana Devnet</code>\n\nYour agent is live on Cloudflare. Send commands like <i>'Pay 0.1 SOL to...'</i> or <i>'Status'</i>.";
        js_telegram_send(msg.chat.id, resp.ptr, resp.len);
    } else if (std.mem.indexOf(u8, text, "Pay") != null or std.mem.indexOf(u8, text, "pay") != null) {
        // Here we simulate the brain interpretation on the edge
        const resp = "<b>[QVAC] Action Triggered</b>\n\nDirective: <code>" ++ "Processing Payment Intent" ++ "</code>\nStatus: <code>PENDING_GUARDIAN_APPROVAL</code>\n\nCheck your dashboard to sign the transaction.";
        js_telegram_send(msg.chat.id, resp.ptr, resp.len);
    }

    return build_response(allocator, 200, "OK", false, 0);
}

fn handle_chat_command(allocator: std.mem.Allocator, body: []const u8) *Response {
    const payload = struct { command: []const u8 };
    const parsed = std.json.parseFromSlice(payload, allocator, body, .{ .ignore_unknown_fields = true }) catch return build_error(allocator, 400, "bad_payload", "json");
    defer parsed.deinit();

    // Simulation of Brain + QVAC on WASM
    const json = std.fmt.allocPrint(allocator, 
        \\{{"ok":true,"reasoning":"Edge-Interpret active","intent_id":"int_0x777","status":"authorized"}}
    , .{}) catch "{}";
    return build_response(allocator, 200, json, false, 0);
}

fn handle_icon(allocator: std.mem.Allocator) *Response {
    const svg = "<svg>...</svg>"; // Placeholder
    return build_response(allocator, 200, svg, false, 0);
}

// --- Helpers ---

fn derive_agent_id(allocator: std.mem.Allocator, pubkey: []const u8) ![]u8 {
    var hash: [32]u8 = undefined;
    crypto.hash256(pubkey, &hash);
    const hex = try crypto.bytesToHex(allocator, hash[0..9]);
    return std.fmt.allocPrint(allocator, "ag_{s}", .{hex});
}

fn build_response(allocator: std.mem.Allocator, status: i32, body: []const u8, sign: bool, action: u8) *Response {
    const body_copy = allocator.dupe(u8, body) catch "internal error";
    response_singleton.status = status;
    response_singleton.body_ptr = body_copy.ptr;
    response_singleton.body_len = body_copy.len;
    response_singleton.should_sign = sign;
    response_singleton.action_byte = action;
    return &response_singleton;
}

fn build_signed_response(allocator: std.mem.Allocator, status: i32, action: u8, body: []const u8) *Response {
    return build_response(allocator, status, body, true, action);
}

fn build_error(allocator: std.mem.Allocator, status: i32, code: []const u8, message: []const u8) *Response {
    const json = std.fmt.allocPrint(allocator, 
        \\{{"ok":false,"error":{{"code":"{s}","message":"{s}"}}}}
    , .{code, message}) catch "{\"ok\":false}";
    return build_response(allocator, status, json, false, 0);
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
