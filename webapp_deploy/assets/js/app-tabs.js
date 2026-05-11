const { useState: _appUseState, useEffect: _appUseEffect } = React;
const _APP_TABS = [
  { id: "wallet", label: "Wallet" },
  { id: "agents", label: "Agents" },
  { id: "pipelines", label: "Pipelines" },
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
      mesh: window.MeshTab,
      explorer: window.ExplorerTab
    };
    const Cmp = map[active];
    if (!Cmp) {
      return /* @__PURE__ */ React.createElement("div", { style: { padding: "48px 0", color: "var(--text-soft)", fontFamily: "var(--mono)", fontSize: 12 } }, '// tab "', active, '" not loaded');
    }
    return /* @__PURE__ */ React.createElement(Cmp, null);
  };
  return /* @__PURE__ */ React.createElement("div", { className: "xb-app-shell", style: { minHeight: "100vh", padding: "80px 24px 48px", background: "var(--bg, #08080a)" } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1280, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(
    "a",
    {
      href: "/index.html#home",
      style: {
        display: "inline-block",
        marginBottom: 20,
        fontFamily: "var(--mono)",
        fontSize: 11,
        color: "var(--text-soft)",
        letterSpacing: "0.08em",
        textDecoration: "none",
        textTransform: "uppercase",
        transition: "color 0.15s"
      },
      onMouseEnter: (e) => {
        e.target.style.color = "var(--accent)";
      },
      onMouseLeave: (e) => {
        e.target.style.color = "var(--text-soft)";
      }
    },
    "\u2190 xb77.io"
  ), /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 32 } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: "var(--text-soft)", letterSpacing: "0.1em", marginBottom: 8 } }, "// APP"), /* @__PURE__ */ React.createElement("h1", { style: { fontFamily: "var(--serif)", fontSize: "clamp(2rem,5vw,3.5rem)", margin: 0, color: "var(--text)", lineHeight: 1.05, fontStyle: "italic" } }, "Sovereign commerce surface."), /* @__PURE__ */ React.createElement("p", { style: { color: "var(--text-soft)", marginTop: 12, fontFamily: "var(--mono)", fontSize: 12, letterSpacing: "0.04em" } }, "wallet / agents / pipelines / mesh / explorer \u2014 one origin.")), /* @__PURE__ */ React.createElement("div", { role: "tablist", "aria-label": "App sections", style: {
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
          transition: "color 0.15s, border-color 0.15s"
        }
      },
      t.label
    );
  })), /* @__PURE__ */ React.createElement("div", { role: "tabpanel", style: { position: "relative" } }, renderTab())));
}
window._AppView = AppView;
