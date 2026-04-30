// xB77 Sovereign Gateway JS Bridge (Dumb Pipe Mode)
import wasmModule from "./gateway.wasm";

export default {
  async fetch(request, env, ctx) {
    const instance = await WebAssembly.instantiate(wasmModule, {
      wasi_snapshot_preview1: {
        proc_exit: (code) => console.log("Exit", code),
        fd_write: () => 0,
      },
      env: {
        js_kv_get: (key_ptr, key_len) => {
          const key = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, key_ptr, key_len));
          // Esta es una limitación de WASM síncrono: KV es asíncrono.
          // Para un sistema real, usaríamos un buffer pre-cargado o Top-level await si es posible.
          // Por ahora, simulamos el bridge. En prod, el Worker cargaría el estado antes de llamar a WASM.
          return 0; 
        },
        js_kv_get_len: (key_ptr, key_len) => 0,
        js_kv_put: (key_ptr, key_len, val_ptr, val_len) => {
          const mem = new Uint8Array(instance.exports.memory.buffer);
          const key = new TextDecoder().decode(mem.slice(key_ptr, key_ptr + key_len));
          const val = mem.slice(val_ptr, val_ptr + val_len);
          ctx.waitUntil(env.XB77_KV.put(key, val));
        },
        js_telegram_send: async (chat_id, text_ptr, text_len) => {
          const text = new TextDecoder().decode(new Uint8Array(instance.exports.memory.buffer, text_ptr, text_len));
          ctx.waitUntil(fetch(`https://api.telegram.org/bot${env.TELEGRAM_TOKEN}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ chat_id: chat_id.toString(), text: text })
          }));
        }
      }
    });

    const url = new URL(request.url);
    const method = request.method;
    const body = await request.arrayBuffer();

    // --- Pre-fetching Logic (The God Protocol Bridge) ---
    let prefetch_keys = [];
    if (url.pathname.startsWith("/balance/")) {
      prefetch_keys.push(url.pathname.split("/")[2]);
    } else if (method === "POST" && (url.pathname === "/deploy" || url.pathname === "/export")) {
      try {
        const json = JSON.parse(new TextDecoder().decode(body));
        if (json.agent_id && Array.isArray(json.agent_id)) {
          const agent_id_hex = Array.from(json.agent_id).map(b => b.toString(16).padStart(2, '0')).join('');
          prefetch_keys.push(agent_id_hex);
          
          if (url.pathname === "/export") {
            // Pre-cargar TODO el estado para el Sovereign Export
            prefetch_keys.push(`cfg_${agent_id_hex}`);
            prefetch_keys.push(`ledger_${agent_id_hex}`);
            prefetch_keys.push(`vault_${agent_id_hex}`);
            prefetch_keys.push(`hist_ops_${agent_id_hex}`);
            prefetch_keys.push(`hist_res_${agent_id_hex}`);
            prefetch_keys.push(`hist_yld_${agent_id_hex}`);
          }
        }
      } catch (e) {}
    } else if (url.pathname === "/webhook/telegram" && method === "POST") {
      try {
        const json = JSON.parse(new TextDecoder().decode(body));
        if (json.message && json.message.chat && json.message.chat.id) {
          const chat_id = json.message.chat.id.toString();
          prefetch_keys.push(`tg_${chat_id}`);
          // Si ya tenemos el tg_{chat_id}, también querremos el status del agente
          const agent_id_hex = await env.XB77_KV.get(`tg_${chat_id}`);
          if (agent_id_hex) prefetch_keys.push(agent_id_hex);
        }
      } catch (e) {}
    } else if (url.pathname === "/link" && method === "POST") {
      try {
        const json = JSON.parse(new TextDecoder().decode(body));
        if (json.link_code) prefetch_keys.push(`link_${json.link_code}`);
      } catch (e) {}
    }

    for (const key of prefetch_keys) {
      const kv_val = await env.XB77_KV.get(key, { type: "arrayBuffer" });
      if (kv_val) {
        const key_ptr = copyToWasm(instance, new TextEncoder().encode(key));
        const val_ptr = copyToWasm(instance, new Uint8Array(kv_val));
        instance.exports.inject_kv_cache(key_ptr, key.length, val_ptr, kv_val.byteLength);
      }
    }

    // Pasar TODO a Zig
    const method_ptr = copyToWasm(instance, new TextEncoder().encode(method));
    const url_ptr = copyToWasm(instance, new TextEncoder().encode(url.pathname));
    const body_ptr = copyToWasm(instance, new Uint8Array(body));

    const resp_ptr = instance.exports.handle_request(
      method_ptr, method.length,
      url_ptr, url.pathname.length,
      body_ptr, body.byteLength
    );

    // Leer respuesta de la estructura de Zig
    const mem = new DataView(instance.exports.memory.buffer);
    const status = mem.getInt32(resp_ptr, true);
    const body_res_ptr = mem.getUint32(resp_ptr + 4, true);
    const body_res_len = mem.getUint32(resp_ptr + 8, true);

    const response_body = new Uint8Array(instance.exports.memory.buffer, body_res_ptr, body_res_len);
    const final_body = new Uint8Array(response_body); // Copiar antes de liberar

    instance.exports.free_response();

    return new Response(final_body, { status: status });
  }
};

function copyToWasm(instance, data) {
  const ptr = instance.exports.alloc(data.length);
  const mem = new Uint8Array(instance.exports.memory.buffer);
  mem.set(data, ptr);
  return ptr;
}
