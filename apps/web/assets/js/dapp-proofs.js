const VERIFIER_PROGRAM_ID = "J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ";
const POLL_INTERVAL_MS = 5e3;
function ProofsView() {
  const [items, setItems] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [err, setErr] = React.useState(null);
  const [lastFetched, setLastFetched] = React.useState(null);
  const refresh = React.useCallback(async () => {
    setLoading(true);
    try {
      const base = window.XB77_GATEWAY || "http://127.0.0.1:8787";
      const r = await fetch(`${base}/api/v1/pipelines/recent?limit=50`);
      if (!r.ok) throw new Error("HTTP " + r.status);
      const data = await r.json();
      const zkOnly = (data.pipelines || []).filter((p) => p.kind === "zk");
      setItems(zkOnly);
      setLastFetched(Date.now());
      setErr(null);
    } catch (e) {
      setErr(e.message || "fetch failed");
    } finally {
      setLoading(false);
    }
  }, []);
  React.useEffect(() => {
    refresh();
    const id = setInterval(refresh, POLL_INTERVAL_MS);
    return () => clearInterval(id);
  }, [refresh]);
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 20px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", justifyContent: "space-between" } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Proofs"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 4, fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, "xb77_zk_verifier \xB7 ", VERIFIER_PROGRAM_ID.slice(0, 12), "\u2026")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 8, alignItems: "center" } }, lastFetched && /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: D.faint } }, Math.floor((Date.now() - lastFetched) / 1e3), "s ago"), /* @__PURE__ */ React.createElement(DBtn, { small: true, onClick: refresh, disabled: loading }, loading ? "\u2026REFRESHING" : "\u21BB REFRESH"))), err && /* @__PURE__ */ React.createElement("div", { style: { padding: "6px 20px", background: `${D.red}18`, borderBottom: `1px solid ${D.border}`, fontFamily: "var(--mono)", fontSize: 10, color: D.red } }, err), /* @__PURE__ */ React.createElement("div", { style: { padding: "12px 20px", borderBottom: `1px solid ${D.border}`, background: "transparent" } }, /* @__PURE__ */ React.createElement(DM, { size: 9, color: D.faint }, "// To generate a new proof from this machine, run in another terminal:"), /* @__PURE__ */ React.createElement("pre", { style: {
    margin: "6px 0 0",
    padding: "8px 10px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    color: D.text,
    fontFamily: "var(--mono)",
    fontSize: 10,
    overflow: "auto",
    whiteSpace: "pre"
  } }, `./zig-out/bin/xb77 -p myagent zk prove --upload`)), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, items.length === 0 && !loading && !err && /* @__PURE__ */ React.createElement("div", { style: { padding: "60px 20px", textAlign: "center", color: D.faint } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 32, marginBottom: 12 } }, "\u{1F4DC}"), /* @__PURE__ */ React.createElement(DM, { size: 10 }, "No verifier transactions yet."), /* @__PURE__ */ React.createElement(DM, { size: 9, color: D.faint }, "The watch daemon polls every 5 seconds.")), items.map((p, idx) => {
    const sig = p.signature || (p.id || "").replace(/^pipe:/, "");
    const verdictColor = p.verdict === "VALID" ? D.green || "#7fbf3f" : D.red;
    return /* @__PURE__ */ React.createElement("div", { key: sig + ":" + idx, style: {
      padding: "14px 20px",
      borderBottom: `1px solid ${D.border}`,
      display: "flex",
      gap: 16,
      alignItems: "center",
      justifyContent: "space-between"
    } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 4, minWidth: 0, flex: 1 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 8, alignItems: "center" } }, /* @__PURE__ */ React.createElement(Badge, { color: verdictColor, bg: `${verdictColor}18` }, p.verdict || "PENDING"), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text, fontWeight: 600 } }, sig.slice(0, 16), "\u2026", sig.slice(-8))), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 12, flexWrap: "wrap" } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, "slot ", p.slot ?? "\u2014"), /* @__PURE__ */ React.createElement(DM, { size: 9 }, "agent ", (p.agent || "onchain").slice(0, 14), "\u2026"), p.duration_ms != null && /* @__PURE__ */ React.createElement(DM, { size: 9 }, Math.floor(p.duration_ms / 1e3), "s"))), /* @__PURE__ */ React.createElement("div", { style: { flexShrink: 0 } }, /* @__PURE__ */ React.createElement(
      "a",
      {
        href: typeof window !== "undefined" && (window.location.hostname.endsWith(".workers.dev") || window.location.hostname.includes("xb77.io")) ? `https://solscan.io/tx/${sig}?cluster=devnet` : `https://solscan.io/tx/${sig}?cluster=custom&customUrl=http%3A%2F%2F127.0.0.1%3A8899`,
        target: "_blank",
        rel: "noopener noreferrer",
        style: {
          fontFamily: "var(--mono)",
          fontSize: 9,
          color: D.accent,
          textDecoration: "none",
          whiteSpace: "nowrap"
        }
      },
      "explorer \u2197"
    )));
  }))));
}
function ProofsTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    border: `1px solid ${D.border}`,
    background: D.bg2,
    borderRadius: 4,
    overflow: "hidden",
    minHeight: 600,
    display: "flex",
    flexDirection: "column"
  } }, /* @__PURE__ */ React.createElement(ProofsView, null));
}
Object.assign(window, { ProofsView, ProofsTab });
