// xB77 Deluxe Gateway Bridge — JS Wrapper for Sovereign Zig Engine.
// Implementation of docs/api-contract-v1.md using WASM for pure logic.

import wasmModule from "../gateway.wasm";

// ────────────────────────── Constants ──────────────────────────

const ACTION_BYTE = {
  submit_order: 0x01,
  register_agent: 0x02,
  claim_credits: 0x03,
  query_pulse: 0x04,
  link_agent: 0x05,
};

const TS_SKEW_MS = 30_000;

// ────────────────────────── Hex Helpers ──────────────────────────

function fromHex(s) {
  if (!s || s.length % 2 !== 0) return null;
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function toHex(b) {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

function u64beBytes(n) {
  const out = new Uint8Array(8);
  let bn = BigInt(n);
  for (let i = 7; i >= 0; i--) {
    out[i] = Number(bn & 0xffn);
    bn >>= 8n;
  }
  return out;
}

// ────────────────────────── Crypto ──────────────────────────

const PKCS8_PREFIX = new Uint8Array([0x30,0x2e,0x02,0x01,0x00,0x30,0x05,0x06,0x03,0x2b,0x65,0x70,0x04,0x22,0x04,0x20]);

async function importGatewayPriv(privHex) {
  const bytes = fromHex(privHex);
  const seed = bytes.slice(0, 32);
  const pkcs8 = new Uint8Array(PKCS8_PREFIX.length + 32);
  pkcs8.set(PKCS8_PREFIX);
  pkcs8.set(seed, PKCS8_PREFIX.length);
  const key = await crypto.subtle.importKey("pkcs8", pkcs8, "Ed25519", false, ["sign"]);
  return { signKey: key, pubkey: bytes.slice(32, 64) };
}

// ────────────────────────── WASM Bridge ──────────────────────────

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // 1. Pre-fetching & Context Preparation
    const kv_cache = new Map();
    const effects = [];

    // Identify Agent for pre-fetching
    const pkHex = request.headers.get("X-Xb77-Pubkey");
    if (pkHex) {
      // Derive Agent ID (simple sha256 mock in JS for pre-fetch)
      const pkBytes = fromHex(pkHex);
      if (pkBytes) {
        const hash = await crypto.subtle.digest("SHA-256", pkBytes);
        const agent_id = "ag_" + toHex(new Uint8Array(hash).slice(0, 9));
        
        // Fetch Agent Data
        const agentData = await env.AGENTS.get(`agent:${agent_id}`);
        if (agentData) kv_cache.set(`agent:${agent_id}`, agentData);

        // Pre-fetch Nonce if present
        const nonceHex = request.headers.get("X-Xb77-Nonce");
        if (nonceHex) {
          const nonceKey = `nonce:${agent_id}:${nonceHex}`;
          const seen = await env.NONCES.get(nonceKey);
          if (seen) kv_cache.set(nonceKey, seen);
        }
      }
    }

    // 2. Instantiate WASM
    const wasi_shim = {
      fd_write: (fd, iovs, iovs_len, nwritten) => 0,
      fd_close: (fd) => 0,
      fd_seek: (fd, offset_low, offset_high, whence, new_offset) => 0,
      proc_exit: (code) => {},
      args_sizes_get: (argc, argv_buf_size) => 0,
      args_get: (argv, argv_buf) => 0,
      environ_sizes_get: (env_count, env_buf_size) => 0,
      environ_get: (env, env_buf) => 0,
      clock_time_get: (id, precision, time_out) => 0,
      fd_read: (fd, iovs, iovs_len, nread) => 0,
      fd_pread: (fd, iovs, iovs_len, offset, nread) => 0,
      fd_write: (fd, iovs, iovs_len, nwritten) => 0,
      fd_pwrite: (fd, iovs, iovs_len, offset, nwritten) => 0,
      fd_close: (fd) => 0,
      fd_seek: (fd, offset_low, offset_high, whence, new_offset) => 0,
      fd_filestat_get: (fd, buf) => 0,
      fd_fdstat_get: (fd, buf) => 0,
      fd_prestat_get: (fd, buf) => 8,
      fd_prestat_dir_name: (fd, path, path_len) => 8,
      path_open: (fd, dirflags, path, path_len, oflags, fs_rights_base, fs_rights_inheriting, fdflags, opened_fd) => 8,
      path_filestat_get: (fd, flags, path, path_len, buf) => 8,
      proc_exit: (code) => {},
      random_get: (buf, len) => {
        crypto.getRandomValues(new Uint8Array(instance.exports.memory.buffer, buf, len));
        return 0;
      },
    };

    const instance = await WebAssembly.instantiate(wasmModule, {
      wasi_snapshot_preview1: wasi_shim,
      env: {
        js_kv_get: (ptr, len) => {
          const key = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, ptr, len));
          const val = kv_cache.get(key);
          if (!val) return 0;
          return copyToWasm(instance, new TextEncoder().encode(val));
        },
        js_kv_get_len: (ptr, len) => {
          const key = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, ptr, len));
          const val = kv_cache.get(key);
          return val ? val.length : 0;
        },
        js_kv_put: (kPtr, kLen, vPtr, vLen, ttl) => {
          const key = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, kPtr, kLen));
          const val = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, vPtr, vLen));
          effects.push({ type: "kv_put", key, val, ttl });
        },
        js_telegram_send: (chat_id, ptr, len) => {
          const text = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, ptr, len));
          effects.push({ type: "telegram", chat_id, text });
        },
        js_fly_spawn: (ptr, len) => {
          const agent_id = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, ptr, len));
          effects.push({ type: "fly_spawn", agent_id });
        },
        js_rpc_call: (mPtr, mLen, pPtr, pLen) => {
          const method = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, mPtr, mLen));
          const params = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, pPtr, pLen));
          const cacheKey = `rpc:${method}:${params}`;
          const cached = kv_cache.get(cacheKey) || '{"result":0}';
          
          const bytes = new TextEncoder().encode(cached + '\0');
          return copyToWasm(instance, bytes);
        },
        js_now: () => BigInt(Date.now()),
        js_fetch: (mPtr, mLen, uPtr, uLen, bPtr, bLen) => {
          const method = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, mPtr, mLen));
          const url = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, uPtr, uLen));
          const body = bLen > 0 ? new Uint8Array(instance.exports.memory.buffer, bPtr, bLen) : null;
          
          // Note: Cloudflare Workers fetch is async, but WASM expect sync here or we need a promise-based bridge.
          // For now, if we are in a sync path in Zig, we use ctx.waitUntil for side effects or we pre-fetch.
          // BUT, for a Deluxe product, we should use the 'deasync' pattern or a sync-bridge if available.
          // Since we can't easily do sync fetch in Workers, we'll mark this for pre-fetch OR return an error 
          // if not pre-cached. 
          
          const cacheKey = `fetch:${method}:${url}`;
          const cached = kv_cache.get(cacheKey);
          if (cached) {
            return copyToWasm(instance, new TextEncoder().encode(cached));
          }
          
          // Fallback: If not cached, we return 0 (error) and the Zig side should handle it.
          // In the next turn, we could implement a more robust async-to-sync bridge.
          return 0;
        }
      }
    });

    // 3. Pre-fetching RPC data for Pulse & Registration
    if (path === "/api/v1/network/pulse") {
      try {
        const rpcResp = await fetch(env.ZNODE_RPC_URL, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getSlot", params: [] })
        });
        const rpcJson = await rpcResp.text();
        kv_cache.set("rpc:getSlot:[]", rpcJson);
      } catch (e) {}
    } else if (path === "/api/v1/actions/register_agent" && pkHex) {
      try {
        const rpcResp = await fetch(env.ZNODE_RPC_URL, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getBalance", params: [pkHex] })
        });
        const rpcJson = await rpcResp.text();
        kv_cache.set(`rpc:getBalance:${pkHex}`, rpcJson);
      } catch (e) {}
    }

    // 3. Inject Cache into WASM
    for (const [k, v] of kv_cache) {
      const kBytes = new TextEncoder().encode(k);
      const vBytes = new TextEncoder().encode(v);
      const kPtr = copyToWasm(instance, kBytes);
      const vPtr = copyToWasm(instance, vBytes);
      instance.exports.inject_kv_cache(kPtr, kBytes.length, vPtr, vBytes.length);
    }

    // 4. Handle Request in WASM
    const body = new Uint8Array(await request.arrayBuffer());
    const methodBytes = new TextEncoder().encode(method);
    const pathBytes = new TextEncoder().encode(path);
    const pkBytes = fromHex(pkHex || "") || new Uint8Array(0);
    const sigBytes = fromHex(request.headers.get("X-Xb77-Signature") || "") || new Uint8Array(0);
    const nonceBytes = fromHex(request.headers.get("X-Xb77-Nonce") || "") || new Uint8Array(0);
    const ts = BigInt(request.headers.get("X-Xb77-Timestamp") || "0");
    const idempBytes = new TextEncoder().encode(request.headers.get("X-Idempotency-Key") || "");

    const respPtr = instance.exports.handle_request(
      copyToWasm(instance, methodBytes), methodBytes.length,
      copyToWasm(instance, pathBytes), pathBytes.length,
      copyToWasm(instance, body), body.length,
      copyToWasm(instance, new TextEncoder().encode(pkHex || "")), (pkHex || "").length,
      copyToWasm(instance, new TextEncoder().encode(request.headers.get("X-Xb77-Signature") || "")), (request.headers.get("X-Xb77-Signature") || "").length,
      ts,
      copyToWasm(instance, new TextEncoder().encode(request.headers.get("X-Xb77-Nonce") || "")), (request.headers.get("X-Xb77-Nonce") || "").length,
      copyToWasm(instance, idempBytes), idempBytes.length
    );

    // Read Response Singleton
    const view = new DataView(instance.exports.memory.buffer);
    const status = view.getInt32(respPtr, true);
    const bodyPtr = view.getUint32(respPtr + 4, true);
    const bodyLen = view.getUint32(respPtr + 8, true);
    const actionByte = view.getUint8(respPtr + 12);
    const shouldSign = view.getUint8(respPtr + 13) !== 0;

    const respBody = new Uint8Array(instance.exports.memory.buffer, bodyPtr, bodyLen);
    const finalBody = new Uint8Array(respBody); // Copy before free

    // 5. Execute Effects
    for (const effect of effects) {
      if (effect.type === "kv_put") {
        const ns = effect.key.startsWith("agent:") ? env.AGENTS : 
                   effect.key.startsWith("nonce:") ? env.NONCES : env.AGENTS;
        await ns.put(effect.key, effect.val, effect.ttl ? { expirationTtl: effect.ttl } : {});
      } else if (effect.type === "telegram") {
        ctx.waitUntil(sendTelegram(effect.chat_id, effect.text, env));
      }
    }

    // 6. Final Response Preparation
    const headers = {
      "content-type": "application/json",
      "access-control-allow-origin": env.ALLOWED_ORIGIN || "*",
      "access-control-allow-headers": "*",
      "access-control-expose-headers": "*",
    };

    if (shouldSign) {
      const gatewayKeys = await importGatewayPriv(env.GATEWAY_PRIVKEY_HEX || env.GATEWAY_PRIVKEY_HEX_DEV);
      const respTs = Date.now();
      // actionByte (1) || ts_be_ms (8) || body (N)
      const canonical = new Uint8Array(1 + 8 + finalBody.length);
      canonical[0] = actionByte;
      canonical.set(u64beBytes(respTs), 1);
      canonical.set(finalBody, 9);
      
      const sigBuf = await crypto.subtle.sign("Ed25519", gatewayKeys.signKey, canonical);
      headers["x-xb77-gateway-timestamp"] = String(respTs);
      headers["x-xb77-gateway-signature"] = toHex(new Uint8Array(sigBuf));
    }

    return new Response(finalBody, { status, headers });
  }
};

function copyToWasm(instance, data) {
  if (data.length === 0) return 0;
  const ptr = instance.exports.alloc(data.length);
  if (ptr === 0) throw new Error("WASM alloc failed");
  const mem = new Uint8Array(instance.exports.memory.buffer);
  mem.set(data, ptr);
  return ptr;
}

async function sendTelegram(chat_id, text, env) {
  if (!env.TELEGRAM_TOKEN) return;
  const url = `https://api.telegram.org/bot${env.TELEGRAM_TOKEN}/sendMessage`;
  await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id, text, parse_mode: "HTML" }),
  });
}
