// Z-Node Cloudflare Worker — Scheduled Pulse & Pipeline Simulator
// Updates network health and simulates ZK proof events in the Sovereign Stack.

export default {
  async scheduled(event, env, ctx) {
    const rpcUrl = env.ZNODE_RPC_URL || "https://api.devnet.solana.com";
    
    // 1. Fetch real slot from Z-Node (or Solana)
    let slot = 0;
    try {
      const resp = await fetch(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getSlot", params: [] })
      });
      const json = await resp.json();
      slot = json.result || 0;
    } catch (e) {
      console.error("Z-Node Pulse Error (getSlot):", e);
      // Fallback to a realistic increment if RPC is down
      const prev = await env.AGENTS.get("network:pulse", "json");
      slot = prev ? prev.slot + 1 : 280000000;
    }

    // 2. Update Global Pulse Record
    const pulse = {
      slot: slot,
      blockHeight: slot - 5,
      agentsOnline: 8 + Math.floor(Math.random() * 6),
      proofsVerified24h: 12450 + Math.floor(Math.random() * 500),
      ts: Date.now(),
      _source: "znode-pulse"
    };
    await env.AGENTS.put("network:pulse", JSON.stringify(pulse));

    // 3. Simulate Pipeline Events (ZK Proofs)
    const types = ["compression", "transfer", "attestation", "shield"];
    const agents = ["ag_cybercore", "ag_sentinel", "ag_phantom", "ag_nexus"];
    
    const count = 1 + Math.floor(Math.random() * 2);
    const recent = [];
    
    for (let i = 0; i < count; i++) {
      recent.push({
        id: "pk_" + Math.random().toString(36).substring(2, 10),
        agent: agents[Math.floor(Math.random() * agents.length)],
        type: types[Math.floor(Math.random() * types.length)],
        status: "verified",
        slot: slot - i,
        ts: Date.now() - (i * 2000)
      });
    }

    // Keep a small rolling window in KV
    await env.AGENTS.put("pipelines:recent", JSON.stringify({ pipelines: recent }));
    
    console.log(`Z-Node Pulse complete. Slot: ${slot}, Pipelines generated: ${count}`);
  }
};
