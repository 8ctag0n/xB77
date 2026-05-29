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

    // 3. Process REAL Agents and Simulate Autonomy
    const agentList = await env.AGENTS.list({ prefix: "agent:" });
    const recent = [];

    for (const key of agentList.keys) {
      const agentData = await env.AGENTS.get(key.name, "json");
      if (!agentData) continue;

      const strategy = agentData.tier || "Sovereign Core";
      
      // Simulate an action based on strategy
      let actionType = "heartbeat";
      if (strategy.includes("Yield")) actionType = "rebalance";
      else if (strategy.includes("Settler")) actionType = "settlement";
      else if (strategy.includes("Rebalancer")) actionType = "bridge";

      recent.push({
        id: "pk_" + Math.random().toString(36).substring(2, 10),
        agent: agentData.agent_id,
        type: actionType,
        status: "verified",
        slot: slot,
        strategy: strategy,
        ts: Date.now()
      });
    }

    // 4. Fallback generic events if no agents yet
    if (recent.length < 3) {
      const genericAgents = ["ag_cybercore", "ag_sentinel"];
      for (const a of genericAgents) {
        recent.push({
          id: "pk_gen_" + Math.random().toString(36).substring(2, 10),
          agent: a,
          type: "shield",
          status: "verified",
          slot: slot - 1,
          ts: Date.now() - 5000
        });
      }
    }

    // Keep a small rolling window in KV
    await env.AGENTS.put("pipelines:recent", JSON.stringify({ pipelines: recent.slice(0, 10) }));
    
    console.log(`Z-Node Pulse complete. Slot: ${slot}, Pipelines generated: ${count}`);
  }
};
