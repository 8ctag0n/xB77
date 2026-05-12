/**
 * SNS reverse-lookup helper.
 *
 * Exposes window.XB77SnsReverseLookup as a (pubkey) => Promise<string | null>
 * function. dapp-actions.js#identity.resolveFavoriteDomain picks it up
 * automatically; ConnectionPill listens for xb77:domain-resolved and swaps
 * the agent ID for the resolved <name>.sol once it lands.
 *
 * Lookups go through the Worker's /api/v1/sns/reverse endpoint (which proxies
 * to Bonfida's SNS API and caches in KV). Browser-side we keep a
 * sessionStorage cache so repeat connect/disconnect cycles in the same tab
 * don't re-hit the network.
 */
(function () {
  const G = typeof window !== "undefined" ? window : globalThis;
  const GATEWAY = G.XB77_GATEWAY || ""; // same-origin '' resolves to "/api/v1/..."
  const TTL_MS = 60 * 60 * 1000; // 1 hour client-side
  const SS_KEY_PREFIX = "xb77:sns:reverse:";

  /**
   * @param {string | Uint8Array} pubkey  Base58 address (string) or raw 32-byte Uint8Array.
   * @returns {Promise<string | null>}    "<name>.sol" or null if no domain.
   */
  async function reverseLookup(pubkey) {
    if (!pubkey) return null;
    let addr;
    if (typeof pubkey === "string") {
      addr = pubkey.trim();
    } else if (pubkey instanceof Uint8Array && pubkey.length === 32 && typeof G.XB77Base58?.encode === "function") {
      addr = G.XB77Base58.encode(pubkey);
    } else {
      console.warn("[sns-reverse] unsupported pubkey shape:", pubkey);
      return null;
    }
    if (!/^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(addr)) return null;

    // sessionStorage cache check
    try {
      const ssKey = SS_KEY_PREFIX + addr;
      const raw = sessionStorage.getItem(ssKey);
      if (raw) {
        const { sol, ts } = JSON.parse(raw);
        if (Date.now() - ts < TTL_MS) return sol;
        sessionStorage.removeItem(ssKey);
      }
    } catch (_) { /* sessionStorage may be disabled */ }

    // Network call to the Worker (same-origin or via XB77_GATEWAY)
    try {
      const base = GATEWAY || "";
      const url = base + "/api/v1/sns/reverse?pubkey=" + encodeURIComponent(addr);
      const resp = await fetch(url, { headers: { accept: "application/json" } });
      if (!resp.ok) return null;
      const data = await resp.json().catch(() => null);
      const sol = data?.sol || null;

      // cache (positive or null)
      try {
        sessionStorage.setItem(SS_KEY_PREFIX + addr, JSON.stringify({ sol, ts: Date.now() }));
      } catch (_) { /* ignore */ }
      return sol;
    } catch (e) {
      console.warn("[sns-reverse] lookup failed:", e?.message || e);
      return null;
    }
  }

  G.XB77SnsReverseLookup = reverseLookup;
})();
