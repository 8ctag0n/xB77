const REGISTRY_PROGRAM_ID = "HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1";
function decodeMerchant(data) {
  try {
    if (data.length < 4) return null;
    const dv = new DataView(data.buffer, data.byteOffset, data.byteLength);
    let off = 0;
    const idLen = dv.getUint32(off, true);
    off += 4;
    if (idLen > 64 || off + idLen + 32 + 8 + 4 + 8 + 8 + 1 > data.length) return null;
    const idBytes = data.slice(off, off + idLen);
    off += idLen;
    const merchantId = new TextDecoder("utf-8", { fatal: false }).decode(idBytes);
    const owner = data.slice(off, off + 32);
    off += 32;
    const supportedMethods = dv.getBigUint64(off, true);
    off += 8;
    const catalogCount = dv.getUint32(off, true);
    off += 4;
    const createdAt = dv.getBigUint64(off, true);
    off += 8;
    const updatedAt = dv.getBigUint64(off, true);
    off += 8;
    const bump = data[off];
    const ownerHex = Array.from(owner, (b) => b.toString(16).padStart(2, "0")).join("");
    return { merchantId, ownerHex, supportedMethods, catalogCount, createdAt, updatedAt, bump };
  } catch {
    return null;
  }
}
function fmtTs(secs) {
  if (typeof secs === "bigint") secs = Number(secs);
  if (!secs) return "\u2014";
  return new Date(secs * 1e3).toISOString().slice(0, 19).replace("T", " ");
}
function MerchantsView() {
  const [merchants, setMerchants] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [err, setErr] = React.useState(null);
  const [merchantIdInput, setMerchantIdInput] = React.useState("");
  const [methodsInput, setMethodsInput] = React.useState(1);
  const [submitting, setSubmitting] = React.useState(false);
  const [submitMsg, setSubmitMsg] = React.useState(null);
  const refresh = React.useCallback(async () => {
    setLoading(true);
    try {
      const isProd = typeof window !== "undefined" && (window.location.hostname.endsWith(".workers.dev") || window.location.hostname.includes("xb77.io"));
      const RPC_DEFAULT = isProd ? "https://api.devnet.solana.com" : "http://127.0.0.1:8899";
      const rpcUrl = window.XB77_RPC_URL || RPC_DEFAULT;
      const rpc = window.SolanaRpc.create(rpcUrl);
      const entries = await rpc.getProgramAccounts(REGISTRY_PROGRAM_ID, {});
      const decoded = entries.map((e) => {
        const m = decodeMerchant(e.account.data);
        if (!m) return null;
        return { ...m, pubkey: e.pubkey, dataLen: e.account.data.length };
      }).filter(Boolean);
      setMerchants(decoded);
      setErr(null);
    } catch (e) {
      setErr(e.message || "fetch failed");
    } finally {
      setLoading(false);
    }
  }, []);
  React.useEffect(() => {
    refresh();
  }, [refresh]);
  async function handleRegister() {
    if (submitting) return;
    const id = (merchantIdInput || "").trim();
    if (!id) {
      setSubmitMsg("merchant id required");
      return;
    }
    if (id.length > 32) {
      setSubmitMsg("merchant id must be \u226432 bytes");
      return;
    }
    setSubmitting(true);
    setSubmitMsg(null);
    try {
      const r = await fetch("/idls/xb77_registry.json");
      if (!r.ok) throw new Error("IDL fetch failed (" + r.status + ")");
      const idl = await r.json();
      const result = await window.XB77Actions.registerMerchantOnchain({
        idl,
        merchantId: id,
        supportedMethods: BigInt(methodsInput || 1)
      });
      setSubmitMsg("registered: " + result.signature.slice(0, 12) + "\u2026");
      setMerchantIdInput("");
      setTimeout(refresh, 1500);
    } catch (e) {
      const msg = e.message || "register failed";
      if (/already|exists|InvalidPda|already_in_use/i.test(msg)) {
        setSubmitMsg("already registered (or PDA exists)");
      } else {
        setSubmitMsg("error: " + msg);
      }
    } finally {
      setSubmitting(false);
    }
  }
  async function handleSimulatePayment(m) {
    const amount = 0.5;
    if (!window.confirm(`Simulate customer paying ${amount} SOL to merchant ${m.merchantId}?`)) return;
    try {
      setSubmitMsg(`initiating payment to ${m.merchantId}...`);
      const isProd = typeof window !== "undefined" && (window.location.hostname.endsWith(".workers.dev") || window.location.hostname.includes("xb77.io"));
      const RPC_URL = isProd ? "https://api.devnet.solana.com" : "http://127.0.0.1:8899";
      const res = await window.XB77Actions.selfAirdrop({ lamports: amount * 1e9 });
      if (res.ok) {
        setSubmitMsg(`SUCCESS: Payment anchored for ${m.merchantId}. Sig: ${res.signature.slice(0, 8)}...`);
        window.dispatchEvent(new CustomEvent("xb77:income", { detail: { amount: (amount * 160).toFixed(2), merchant: m.merchantId } }));
      } else {
        throw new Error(res.error || "Airdrop limit");
      }
    } catch (e) {
      setSubmitMsg("payment failed: " + e.message);
    }
  }
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { width: 320, borderRight: `1px solid ${D.border}`, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 20px", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Merchants"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 4, fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, "xb77_registry \xB7 ", REGISTRY_PROGRAM_ID.slice(0, 12), "\u2026")), /* @__PURE__ */ React.createElement("div", { style: { padding: 20, display: "flex", flexDirection: "column", gap: 12 } }, /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.text }, "Register new merchant"), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "text",
      placeholder: "merchant id (e.g. cafe-sovereign)",
      value: merchantIdInput,
      onChange: (e) => setMerchantIdInput(e.target.value),
      disabled: submitting,
      style: {
        padding: "8px 10px",
        background: D.bg2,
        color: D.text,
        border: `1px solid ${D.border}`,
        fontFamily: "var(--mono)",
        fontSize: 11,
        outline: "none"
      }
    }
  ), /* @__PURE__ */ React.createElement("label", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, "supported methods (bitmask)"), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "number",
      min: 1,
      value: methodsInput,
      onChange: (e) => setMethodsInput(parseInt(e.target.value, 10) || 1),
      disabled: submitting,
      style: {
        padding: "8px 10px",
        background: D.bg2,
        color: D.text,
        border: `1px solid ${D.border}`,
        fontFamily: "var(--mono)",
        fontSize: 11,
        outline: "none"
      }
    }
  ), /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true, onClick: handleRegister, disabled: submitting }, submitting ? "\u2026REGISTERING" : "REGISTER \u{1F3EA}"), submitMsg && /* @__PURE__ */ React.createElement("div", { style: {
    padding: "6px 8px",
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: /error/.test(submitMsg) ? D.red : D.green || "#7fbf3f",
    background: /error/.test(submitMsg) ? `${D.red}18` : `${D.green || "#7fbf3f"}18`
  } }, submitMsg)), /* @__PURE__ */ React.createElement("div", { style: { padding: "12px 20px", borderTop: `1px solid ${D.border}`, marginTop: "auto" } }, /* @__PURE__ */ React.createElement(DM, { size: 9, color: D.faint }, "// CLI equivalent:"), /* @__PURE__ */ React.createElement("pre", { style: {
    margin: "4px 0 0",
    padding: "6px 8px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    color: D.text,
    fontFamily: "var(--mono)",
    fontSize: 9,
    overflow: "auto"
  } }, `xb77 -p myagent merchant register --id ${merchantIdInput || "<id>"}`))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 20px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", justifyContent: "space-between" } }, /* @__PURE__ */ React.createElement(DM, { size: 10 }, merchants.length, " registered"), /* @__PURE__ */ React.createElement(DBtn, { small: true, onClick: refresh, disabled: loading }, loading ? "\u2026REFRESHING" : "\u21BB REFRESH")), err && /* @__PURE__ */ React.createElement("div", { style: { padding: "6px 20px", background: `${D.red}18`, borderBottom: `1px solid ${D.border}`, fontFamily: "var(--mono)", fontSize: 10, color: D.red } }, err), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, merchants.length === 0 && !loading && !err && /* @__PURE__ */ React.createElement("div", { style: { padding: "60px 20px", textAlign: "center", color: D.faint } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 32, marginBottom: 12 } }, "\u{1F3EA}"), /* @__PURE__ */ React.createElement(DM, { size: 10 }, "No merchants registered yet.")), merchants.map((m) => /* @__PURE__ */ React.createElement("div", { key: m.pubkey, style: {
    padding: "14px 20px",
    borderBottom: `1px solid ${D.border}`,
    display: "flex",
    flexDirection: "column",
    gap: 6
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10 } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 13, color: D.text, fontWeight: 600 } }, m.merchantId), /* @__PURE__ */ React.createElement(Badge, { color: D.cyan || D.accent, bg: `${D.cyan || D.accent}18` }, "methods 0x", m.supportedMethods.toString(16)), /* @__PURE__ */ React.createElement(Badge, { color: D.accent, bg: `${D.accent}18` }, m.catalogCount, " catalogs"), /* @__PURE__ */ React.createElement("span", { style: { flex: 1 } }), /* @__PURE__ */ React.createElement(DBtn, { small: true, onClick: () => handleSimulatePayment(m) }, "PAY MERCHANT \u{1F4B8}")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 14, fontFamily: "var(--mono)", fontSize: 9, color: D.faint } }, /* @__PURE__ */ React.createElement("span", null, "pda ", m.pubkey.slice(0, 8), "\u2026"), /* @__PURE__ */ React.createElement("span", null, "owner ", m.ownerHex.slice(0, 12), "\u2026"), /* @__PURE__ */ React.createElement("span", null, "created ", fmtTs(m.createdAt))))))));
}
function MerchantsTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    border: `1px solid ${D.border}`,
    background: D.bg2,
    borderRadius: 4,
    overflow: "hidden",
    minHeight: 600,
    display: "flex",
    flexDirection: "column"
  } }, /* @__PURE__ */ React.createElement(MerchantsView, null));
}
Object.assign(window, { MerchantsView, MerchantsTab });
