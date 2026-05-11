const _ksHooks = { useState: React.useState, useEffect: React.useEffect, useRef: React.useRef };
function KeystoreModal() {
  const [open, setOpen] = _ksHooks.useState(false);
  const [step, setStep] = _ksHooks.useState("choose");
  const [password, setPassword] = _ksHooks.useState("");
  const [confirmPw, setConfirmPw] = _ksHooks.useState("");
  const [intent, setIntent] = _ksHooks.useState("merchant");
  const [importBlob, setImportBlob] = _ksHooks.useState("");
  const [error, setError] = _ksHooks.useState(null);
  const [result, setResult] = _ksHooks.useState(null);
  const fileRef = _ksHooks.useRef(null);
  _ksHooks.useEffect(() => {
    const onOpen = () => {
      setOpen(true);
      reset();
    };
    const onClose = () => setOpen(false);
    window.addEventListener("xb77:open-keystore", onOpen);
    window.addEventListener("xb77:close-keystore", onClose);
    return () => {
      window.removeEventListener("xb77:open-keystore", onOpen);
      window.removeEventListener("xb77:close-keystore", onClose);
    };
  }, []);
  function reset() {
    setStep("choose");
    setPassword("");
    setConfirmPw("");
    setImportBlob("");
    setError(null);
    setResult(null);
  }
  async function finalize(pubkey, sealedBlob) {
    setStep("working");
    setError(null);
    try {
      window.XB77Actions.keystore.saveSealedBlob(sealedBlob);
      const data = await window.XB77Actions.registerAgent(pubkey, intent);
      setResult({ agent_id: data.agent_id, tier: data.tier, credits: data.credits });
      setStep("done");
      window.dispatchEvent(new CustomEvent("xb77:connected", { detail: { agent_id: data.agent_id } }));
    } catch (e) {
      setError(e.message || "register failed");
      setStep("choose");
    }
  }
  async function handleGenerate() {
    if (!password || password.length < 4) return setError("password too short (min 4)");
    if (password !== confirmPw) return setError("passwords don't match");
    setError(null);
    try {
      const r = await window.XB77Keystore.generate(password);
      finalize(r.pubkeyHex, r.sealedBlob);
    } catch (e) {
      setError(e.message || "keystore generate failed");
    }
  }
  async function handleImport() {
    if (!password) return setError("enter password");
    if (!importBlob) return setError("pick a keystore file");
    setError(null);
    try {
      const r = await window.XB77Keystore.import(importBlob, password);
      finalize(r.pubkeyHex, r.sealedBlob);
    } catch (e) {
      setError(/invalid_password/.test(e.message) ? "wrong password" : e.message || "import failed");
    }
  }
  function onFile(e) {
    const f = e.target.files && e.target.files[0];
    if (!f) return;
    const r = new FileReader();
    r.onload = () => setImportBlob(String(r.result || "").trim());
    r.readAsText(f);
  }
  if (!open) return null;
  const overlay = {
    position: "fixed",
    inset: 0,
    zIndex: 9998,
    background: "rgba(0,0,0,0.55)",
    backdropFilter: "blur(2px)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: 20
  };
  const panel = {
    width: "min(440px, 100%)",
    background: "var(--bg-elevated, #131313)",
    border: "1px solid var(--border-strong, #333)",
    boxShadow: "0 20px 60px rgba(0,0,0,0.45)",
    fontFamily: "var(--mono, ui-monospace, monospace)",
    color: "var(--text, #ddd)"
  };
  const header = {
    padding: "14px 18px",
    borderBottom: "1px solid var(--border-soft, #2a2a2a)",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    fontSize: 11,
    letterSpacing: "0.12em",
    textTransform: "uppercase",
    color: "var(--text-soft, #888)"
  };
  const body = { padding: "18px 18px 6px" };
  const label = { fontSize: 9, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--text-soft, #888)", marginBottom: 6, display: "block" };
  const input = {
    width: "100%",
    padding: "10px 12px",
    background: "var(--bg, #08080a)",
    border: "1px solid var(--border-soft, #2a2a2a)",
    color: "var(--text, #ddd)",
    fontFamily: "var(--mono)",
    fontSize: 12,
    outline: "none",
    marginBottom: 12
  };
  const btn = (primary) => ({
    flex: 1,
    padding: "10px 14px",
    background: primary ? "var(--accent, #c97a3a)" : "transparent",
    color: primary ? "var(--bg, #08080a)" : "var(--text, #ddd)",
    border: primary ? "none" : "1px solid var(--border-strong, #333)",
    fontFamily: "var(--mono)",
    fontSize: 10,
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    fontWeight: 600,
    cursor: "pointer"
  });
  return /* @__PURE__ */ React.createElement("div", { style: overlay, onClick: () => setOpen(false) }, /* @__PURE__ */ React.createElement("div", { style: panel, onClick: (e) => e.stopPropagation() }, /* @__PURE__ */ React.createElement("div", { style: header }, /* @__PURE__ */ React.createElement("span", null, "// keystore \xB7 ", step), /* @__PURE__ */ React.createElement("button", { onClick: () => setOpen(false), style: {
    background: "transparent",
    border: "none",
    color: "inherit",
    fontFamily: "var(--mono)",
    fontSize: 14,
    cursor: "pointer",
    padding: 0
  } }, "\xD7")), /* @__PURE__ */ React.createElement("div", { style: body }, step === "choose" && /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("p", { style: { fontSize: 11, color: "var(--text-soft)", margin: "0 0 16px" } }, "Connect an agent identity. Keystore stays in this browser; private key never leaves the session."), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 10 } }, /* @__PURE__ */ React.createElement("button", { style: btn(true), onClick: () => {
    setError(null);
    setStep("generate");
  } }, "Generate new"), /* @__PURE__ */ React.createElement("button", { style: btn(false), onClick: () => {
    setError(null);
    setStep("import");
  } }, "Import existing")), /* @__PURE__ */ React.createElement("p", { style: { fontSize: 9, color: "var(--text-soft)", marginTop: 18, opacity: 0.7 } }, "wire 1.1 \xB7 Ed25519 via Web Crypto \xB7 AES-GCM at rest")), step === "generate" && /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("label", { style: label }, "Intent"), /* @__PURE__ */ React.createElement("select", { value: intent, onChange: (e) => setIntent(e.target.value), style: input }, /* @__PURE__ */ React.createElement("option", { value: "merchant" }, "merchant"), /* @__PURE__ */ React.createElement("option", { value: "treasury" }, "treasury"), /* @__PURE__ */ React.createElement("option", { value: "trader" }, "trader"), /* @__PURE__ */ React.createElement("option", { value: "indexer" }, "indexer")), /* @__PURE__ */ React.createElement("label", { style: label }, "Password"), /* @__PURE__ */ React.createElement("input", { type: "password", value: password, onChange: (e) => setPassword(e.target.value), style: input, autoFocus: true }), /* @__PURE__ */ React.createElement("label", { style: label }, "Confirm"), /* @__PURE__ */ React.createElement("input", { type: "password", value: confirmPw, onChange: (e) => setConfirmPw(e.target.value), style: input }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 10 } }, /* @__PURE__ */ React.createElement("button", { style: btn(false), onClick: () => setStep("choose") }, "\u2190 Back"), /* @__PURE__ */ React.createElement("button", { style: btn(true), onClick: handleGenerate }, "Generate"))), step === "import" && /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("label", { style: label }, "Keystore file"), /* @__PURE__ */ React.createElement("input", { ref: fileRef, type: "file", accept: ".json,.txt,application/json,text/plain", onChange: onFile, style: { ...input, padding: 8 } }), importBlob && /* @__PURE__ */ React.createElement("div", { style: { fontSize: 9, color: "var(--text-soft)", marginTop: -8, marginBottom: 12 } }, "blob loaded \xB7 ", importBlob.length, " chars"), /* @__PURE__ */ React.createElement("label", { style: label }, "Password"), /* @__PURE__ */ React.createElement("input", { type: "password", value: password, onChange: (e) => setPassword(e.target.value), style: input }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 10 } }, /* @__PURE__ */ React.createElement("button", { style: btn(false), onClick: () => setStep("choose") }, "\u2190 Back"), /* @__PURE__ */ React.createElement("button", { style: btn(true), onClick: handleImport }, "Import"))), step === "working" && /* @__PURE__ */ React.createElement("div", { style: { padding: "24px 0", textAlign: "center", color: "var(--text-soft)", fontSize: 11 } }, "registering agent\u2026"), step === "done" && result && /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 0" } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 10, color: "var(--text-soft)", marginBottom: 6 } }, "// agent registered"), /* @__PURE__ */ React.createElement("div", { style: { fontSize: 14, color: "var(--accent, #c97a3a)", marginBottom: 10 } }, result.agent_id), /* @__PURE__ */ React.createElement("div", { style: { fontSize: 11, color: "var(--text)" } }, "tier: ", /* @__PURE__ */ React.createElement("b", null, result.tier), " \xB7 credits: ", /* @__PURE__ */ React.createElement("b", null, result.credits))), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 10 } }, /* @__PURE__ */ React.createElement("button", { style: btn(true), onClick: () => setOpen(false) }, "Continue"))), error && /* @__PURE__ */ React.createElement("div", { style: {
    marginTop: 8,
    padding: "8px 10px",
    fontSize: 10,
    background: "rgba(248,113,113,0.12)",
    border: "1px solid rgba(248,113,113,0.4)",
    color: "var(--red, #f87171)"
  } }, error)), /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 18px 14px", fontSize: 9, color: "var(--text-soft)", opacity: 0.6, borderTop: "1px solid var(--border-soft)" } }, "esc / click outside to dismiss")));
}
window.KeystoreModal = KeystoreModal;
