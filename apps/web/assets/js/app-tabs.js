const { useState: _appUseState, useEffect: _appUseEffect } = React;
const _APP_TABS = [
  { id: "wallet", label: "Wallet" },
  { id: "agents", label: "Agents" },
  { id: "pipelines", label: "Pipelines" },
  { id: "proofs", label: "Proofs" },
  { id: "merchants", label: "Merchants" },
  { id: "mesh", label: "Mesh" },
  { id: "explorer", label: "Explorer" }
];
function _appParseHash() {
  const m = (window.location.hash || "").match(/^#app(?:\/([\w-]+))?/);
  if (!m) return null;
  const tab = m[1];
  if (tab && _APP_TABS.find((t) => t.id === tab)) return tab;
  return "agents";
}
function ConnectionPill() {
  const [agentId, setAgentId] = _appUseState(() => window.XB77Actions?.keystore.agentId || null);
  const [solDomain, setSolDomain] = _appUseState(() => window.__XB77_SOL_DOMAIN__ || null);
  _appUseEffect(() => {
    const onConn = (ev) => {
      setAgentId(ev?.detail?.agent_id || window.XB77Actions?.keystore.agentId || null);
      try {
        window.XB77Actions?.identity?.resolveFavoriteDomain?.().then((name) => {
          if (name) {
            window.__XB77_SOL_DOMAIN__ = name;
            window.dispatchEvent(new CustomEvent("xb77:domain-resolved", { detail: { sol_domain: name } }));
          }
        }).catch(() => {
        });
      } catch (_) {
      }
    };
    const onDomain = (ev) => setSolDomain(ev?.detail?.sol_domain || null);
    const onDisconn = () => {
      setAgentId(null);
      setSolDomain(null);
      window.__XB77_SOL_DOMAIN__ = null;
    };
    window.addEventListener("xb77:connected", onConn);
    window.addEventListener("xb77:domain-resolved", onDomain);
    window.addEventListener("xb77:disconnected", onDisconn);
    return () => {
      window.removeEventListener("xb77:connected", onConn);
      window.removeEventListener("xb77:domain-resolved", onDomain);
      window.removeEventListener("xb77:disconnected", onDisconn);
    };
  }, []);
  const open = () => window.dispatchEvent(new CustomEvent("xb77:open-keystore"));
  const connected = !!agentId;
  const label = !connected ? "\u25CB Connect" : solDomain ? `\u25CF ${solDomain}` : `\u25CF ${agentId.slice(0, 14)}\u2026`;
  const sovereign = !!solDomain;
  return /* @__PURE__ */ React.createElement(
    "button",
    {
      onClick: open,
      title: connected ? sovereign ? `Sovereign identity: ${solDomain} (Native SNS) \u2014 manage keystore` : "Manage keystore" : "Connect agent",
      style: {
        fontFamily: "var(--mono)",
        fontSize: 10,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        padding: "6px 12px",
        background: sovereign ? "rgba(200,255,46,0.14)" : connected ? "rgba(127,191,63,0.12)" : "transparent",
        color: sovereign ? "var(--lime, #c8ff2e)" : connected ? "var(--green, #7fbf3f)" : "var(--accent, #c97a3a)",
        border: `1px solid ${sovereign ? "rgba(200,255,46,0.45)" : connected ? "rgba(127,191,63,0.4)" : "var(--accent, #c97a3a)"}`,
        cursor: "pointer",
        whiteSpace: "nowrap",
        textShadow: sovereign ? "0 0 8px rgba(200,255,46,0.4)" : "none"
      }
    },
    label
  );
}
function AppView() {
  const [active, setActive] = _appUseState(_appParseHash() || "agents");
  _appUseEffect(() => {
    const onHash = () => {
      const t = _appParseHash();
      if (t && t !== active) setActive(t);
    };
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, [active]);
  _appUseEffect(() => {
    if (window.XB77Actions && !window.XB77Actions.keystore.hasAgent()) {
      const t = setTimeout(() => window.dispatchEvent(new CustomEvent("xb77:open-keystore")), 600);
      return () => clearTimeout(t);
    }
  }, []);
  const setTab = (id) => {
    if (id === active) return;
    window.location.hash = `#app/${id}`;
    setActive(id);
  };
  const renderTab = () => {
    const map = {
      wallet: window.WalletTab,
      agents: window.AgentsTab,
      pipelines: window.PipelinesTab,
      proofs: window.ProofsTab,
      merchants: window.MerchantsTab,
      mesh: window.MeshTab,
      explorer: window.ExplorerTab
    };
    const Cmp = map[active];
    if (!Cmp) {
      return /* @__PURE__ */ React.createElement("div", { style: { padding: "48px 0", color: "var(--text-soft)", fontFamily: "var(--mono)", fontSize: 12 } }, '// tab "', active, '" not loaded');
    }
    return /* @__PURE__ */ React.createElement(Cmp, null);
  };
  return /* @__PURE__ */ React.createElement("div", { className: "xb-app-shell", style: { minHeight: "100vh", padding: "20px 24px 32px", background: "var(--bg, #08080a)" } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1280, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(
    "a",
    {
      href: "/index.html#home",
      style: {
        display: "inline-block",
        marginBottom: 10,
        fontFamily: "var(--mono)",
        fontSize: 11,
        color: "var(--text-soft)",
        letterSpacing: "0.08em",
        textDecoration: "none",
        textTransform: "uppercase",
        transition: "color 0.25s ease"
      },
      onMouseEnter: (e) => {
        e.target.style.color = "var(--accent)";
      },
      onMouseLeave: (e) => {
        e.target.style.color = "var(--text-soft)";
      }
    },
    "\u2190 xb77.io"
  ), /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 18, display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16 } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: "var(--text-soft)", letterSpacing: "0.1em", marginBottom: 4 } }, "// APP"), /* @__PURE__ */ React.createElement("h1", { style: { fontFamily: "var(--serif)", fontSize: "clamp(1.5rem,3.5vw,2.4rem)", margin: 0, color: "var(--text)", lineHeight: 1.1, fontStyle: "italic" } }, "Sovereign commerce surface."), /* @__PURE__ */ React.createElement("p", { style: { color: "var(--text-soft)", marginTop: 6, fontFamily: "var(--mono)", fontSize: 11, letterSpacing: "0.04em" } }, "wallet / agents / pipelines / mesh / explorer \u2014 one origin.")), /* @__PURE__ */ React.createElement(ConnectionPill, null)), /* @__PURE__ */ React.createElement("div", { role: "tablist", "aria-label": "App sections", style: {
    display: "flex",
    gap: 0,
    borderBottom: "1px solid var(--border-soft)",
    marginBottom: 24,
    overflowX: "auto"
  } }, _APP_TABS.map((t) => {
    const isActive = active === t.id;
    return /* @__PURE__ */ React.createElement(
      "button",
      {
        key: t.id,
        role: "tab",
        "aria-selected": isActive,
        onClick: () => setTab(t.id),
        style: {
          padding: "12px 18px",
          background: "transparent",
          border: "none",
          color: isActive ? "var(--accent)" : "var(--text-soft)",
          fontFamily: "var(--mono)",
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: "0.1em",
          textTransform: "uppercase",
          borderBottom: isActive ? "2px solid var(--accent)" : "2px solid transparent",
          marginBottom: "-1px",
          cursor: "pointer",
          whiteSpace: "nowrap",
          transition: "color 0.28s ease, border-color 0.28s ease"
        }
      },
      t.label
    );
  })), /* @__PURE__ */ React.createElement("div", { role: "tabpanel", style: { position: "relative" } }, renderTab())), window.KeystoreModal ? React.createElement(window.KeystoreModal) : null);
}
window._AppView = AppView;
