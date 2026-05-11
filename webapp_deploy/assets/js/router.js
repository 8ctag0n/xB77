const _FILE_HASH = {
  "xB77 v2.html": "#home",
  "dApp.html": "#dapp",
  "Explorer.html": "#explorer",
  "Architecture.html": "#architecture",
  "Docs.html": "#docs",
  "Whitepaper.html": "#whitepaper",
  "Why xB77.html": "#why",
  "Changelog.html": "#changelog"
};
document.addEventListener("click", (e) => {
  const a = e.target.closest("a[href]");
  if (!a) return;
  const href = a.getAttribute("href");
  if (href && _FILE_HASH[href]) {
    e.preventDefault();
    window.location.hash = _FILE_HASH[href];
    window.scrollTo(0, 0);
  }
});
function DemoTour() {
  return null;
}
window.DemoTour = DemoTour;
function useHashRoute() {
  const [hash, setHash] = React.useState(window.location.hash || "");
  React.useEffect(() => {
    const h = () => setHash(window.location.hash || "");
    window.addEventListener("hashchange", h);
    return () => window.removeEventListener("hashchange", h);
  }, []);
  const map = {
    "": "home",
    "#home": "home",
    "#dapp": "dapp",
    "#explorer": "explorer",
    "#architecture": "architecture",
    "#docs": "docs",
    "#whitepaper": "whitepaper",
    "#why": "why",
    "#changelog": "changelog"
  };
  return map[hash] || "home";
}
const ExPipelinesView = window._ExPipelinesView;
function LandingPage() {
  const [variant, setVariant] = React.useState("obsidian");
  const t = THEMES[variant];
  const VMap = { obsidian: ObsidianVariant, deepsignal: DeepSignalVariant, cipher: CipherVariant };
  const V = VMap[variant] || ObsidianVariant;
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", transition: "background 0.3s" } }, /* @__PURE__ */ React.createElement(V, { key: variant, theme: variant }), /* @__PURE__ */ React.createElement("div", { style: {
    position: "fixed",
    bottom: 24,
    right: 24,
    zIndex: 9999,
    display: "flex",
    overflow: "hidden",
    border: `1px solid ${t.border}`,
    background: "rgba(0,0,0,0.85)",
    backdropFilter: "blur(12px)"
  } }, ["obsidian", "deepsignal", "cipher"].map((v) => /* @__PURE__ */ React.createElement("button", { key: v, onClick: () => setVariant(v), style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    fontWeight: 600,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
    background: variant === v ? t.accent : "transparent",
    color: variant === v ? t.bg : t.textDim,
    border: "none",
    padding: "10px 14px",
    cursor: "pointer",
    transition: "all 0.2s"
  } }, v === "deepsignal" ? "Signal" : v))));
}
function DAppPlaceholder({ title, desc, icon }) {
  return /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", alignItems: "center", justifyContent: "center" } }, /* @__PURE__ */ React.createElement("div", { style: { textAlign: "center", maxWidth: 360 } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 48, color: D.faint, marginBottom: 16 } }, icon), /* @__PURE__ */ React.createElement(DS, { size: 28, italic: true }, title), /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 14, color: D.dim, lineHeight: 1.6, marginTop: 12 } }, desc)));
}
function DAppPage() {
  const [page, setPage] = React.useState("dashboard");
  const [notifs] = React.useState(3);
  const nav = [
    { id: "dashboard", icon: "\u25C8", label: "Dashboard" },
    { id: "agents", icon: "\u2B21", label: "Agents", count: 5 },
    { id: "pipelines", icon: "\u25C7", label: "Pipelines", count: 3 },
    { id: "wallet", icon: "\u25C6", label: "Treasury" },
    { id: "merchants", icon: "\u25A3", label: "Merchants", count: 12 },
    { id: "governance", icon: "\u2699", label: "Governance" }
  ];
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", height: "100vh" } }, /* @__PURE__ */ React.createElement("aside", { style: { width: 200, background: D.sidebar, borderRight: `1px solid ${D.border}`, display: "flex", flexDirection: "column", flexShrink: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 18px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", gap: 10 } }, /* @__PURE__ */ React.createElement("a", { href: "xB77 v2.html", style: { fontFamily: "var(--mono)", fontWeight: 700, fontSize: 16, color: D.accent, letterSpacing: "0.06em", textDecoration: "none" } }, "xB77"), /* @__PURE__ */ React.createElement(Badge, null, "LIVE")), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, paddingTop: 8 } }, nav.map((n) => /* @__PURE__ */ React.createElement(NavItem, { key: n.id, icon: n.icon, label: n.label, count: n.count, active: page === n.id, onClick: () => setPage(n.id) }))), /* @__PURE__ */ React.createElement("div", { style: { padding: "14px 18px", borderTop: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 6, marginBottom: 6 } }, /* @__PURE__ */ React.createElement(Dot, { color: D.green, pulse: true }), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.green }, "SWARM ONLINE")), /* @__PURE__ */ React.createElement(DM, { size: 7, color: D.faint }, "5 agents \u2022 3 pipelines")), /* @__PURE__ */ React.createElement("div", { style: { padding: "12px 18px", borderTop: `1px solid ${D.border}`, display: "flex", alignItems: "center", gap: 10 } }, /* @__PURE__ */ React.createElement("div", { style: { width: 28, height: 28, background: D.accentDim, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: "var(--mono)", fontSize: 9, fontWeight: 700, color: D.accent } }, "7x"), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.text } }, "anon_7x8f2"), /* @__PURE__ */ React.createElement(DM, { size: 7, color: D.faint }, "nk_7x8f...a91d")))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", minWidth: 0 } }, /* @__PURE__ */ React.createElement("header", { style: { height: 44, padding: "0 20px", borderBottom: `1px solid ${D.border}`, background: D.topbar, backdropFilter: "blur(12px)", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 } }, /* @__PURE__ */ React.createElement(DS, { size: 16, italic: true }, nav.find((n) => n.id === page)?.label), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 16 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 6, padding: "5px 12px", border: `1px solid ${D.border}`, background: D.bg2, width: 220 } }, /* @__PURE__ */ React.createElement("span", { style: { fontSize: 11, color: D.faint } }, "\u2315"), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, "Search agents, txns...")), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", cursor: "pointer" } }, /* @__PURE__ */ React.createElement("span", { style: { fontSize: 14, color: D.dim } }, "\u{1F514}"), notifs > 0 && /* @__PURE__ */ React.createElement("span", { style: { position: "absolute", top: -4, right: -6, width: 14, height: 14, borderRadius: "50%", background: D.red, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: "var(--mono)", fontSize: 8, fontWeight: 700, color: "#fff" } }, notifs)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 6 } }, /* @__PURE__ */ React.createElement(Dot, { color: D.green, pulse: true }), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.dim }, "SOLANA MAINNET")), /* @__PURE__ */ React.createElement("a", { href: "Explorer.html", style: { fontFamily: "var(--mono)", fontSize: 9, color: D.dim, letterSpacing: "0.1em", textDecoration: "none", textTransform: "uppercase" } }, "EXPLORER"))), /* @__PURE__ */ React.createElement("main", { style: { flex: 1, display: "flex", flexDirection: "column", minHeight: 0 } }, page === "dashboard" && /* @__PURE__ */ React.createElement(DashboardView, null), page === "agents" && /* @__PURE__ */ React.createElement(AgentsView, null), page === "pipelines" && /* @__PURE__ */ React.createElement(PipelinesView, null), page === "wallet" && /* @__PURE__ */ React.createElement(WalletView, null), page === "merchants" && /* @__PURE__ */ React.createElement(DAppPlaceholder, { title: "Merchants", desc: "Browse and manage merchant relationships. Coming soon.", icon: "\u25A3" }), page === "governance" && /* @__PURE__ */ React.createElement(DAppPlaceholder, { title: "Governance", desc: "Agent rules, human overrides, and swarm policies. Coming soon.", icon: "\u2699" }))));
}
const _sparkTVL = Array.from({ length: 20 }, (_, i) => 10 + Math.sin(i * 0.4) * 3 + Math.random() * 2);
const _sparkPipe = Array.from({ length: 20 }, (_, i) => 300 + i * 20 + Math.random() * 60);
const _sparkLat = Array.from({ length: 20 }, (_, i) => 30 + Math.sin(i * 0.6) * 10 + Math.random() * 5);
const _sparkPos = Array.from({ length: 20 }, (_, i) => 50 + i * 8 + Math.random() * 30);
function ExplorerPage() {
  const [search, setSearch] = React.useState("");
  const [tab, setTab] = React.useState("pipelines");
  const [sel, setSel] = React.useState(null);
  const marqueeItems = ["xB77 EXPLORER", "MESH NETWORK", "POSEIDON COMMITS", "APP PROTOCOL", "ZK-VERIFIED", "AUTONOMOUS", "SHIELDED"];
  const tripled = [...marqueeItems, ...marqueeItems, ...marqueeItems];
  const tabs = [
    { id: "pipelines", label: "Pipelines", count: MOCK_PIPELINES.length },
    { id: "poseidon", label: "Poseidon", count: MOCK_POSEIDON.length },
    { id: "agents", label: "Agents", count: MOCK_AGENTS_V2.length },
    { id: "merchants", label: "Merchants", count: MOCK_MERCHANTS.length },
    { id: "znodes", label: "Znodes", count: MOCK_ZNODES.length }
  ];
  return /* @__PURE__ */ React.createElement("div", { style: { minHeight: "100vh", display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { overflow: "hidden", borderBottom: "1px solid rgba(255,255,255,0.05)", background: "rgba(200,255,46,0.04)", height: 28, display: "flex", alignItems: "center", flexShrink: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 36, whiteSpace: "nowrap", animation: "marquee 25s linear infinite", fontFamily: "var(--mono)", fontSize: 9.5, fontWeight: 600, letterSpacing: "0.15em", color: "#c8ff2e", textTransform: "uppercase", opacity: 0.7 } }, tripled.map((item, i) => /* @__PURE__ */ React.createElement("span", { key: i, style: { display: "flex", alignItems: "center", gap: 36 } }, item, " ", /* @__PURE__ */ React.createElement("span", { style: { opacity: 0.25 } }, "\u25C6"))))), /* @__PURE__ */ React.createElement("nav", { style: { background: "rgba(8,8,10,0.92)", backdropFilter: "blur(20px)", borderBottom: `1px solid ${T.border}`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 28px", height: 48, flexShrink: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 14 } }, /* @__PURE__ */ React.createElement("a", { href: "xB77 v2.html", style: { fontFamily: "var(--mono)", fontWeight: 700, fontSize: 16, color: T.accent, letterSpacing: "0.06em", textDecoration: "none" } }, "xB77"), /* @__PURE__ */ React.createElement("div", { style: { width: 1, height: 18, background: T.border } }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--serif)", fontSize: 16, color: T.text, fontStyle: "italic" } }, "Explorer")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 14 } }, /* @__PURE__ */ React.createElement("span", { style: { width: 6, height: 6, borderRadius: "50%", background: T.green, animation: "livePulse 2s ease infinite" } }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.08em" } }, "MESH ONLINE"), /* @__PURE__ */ React.createElement("div", { style: { width: 1, height: 18, background: T.border } }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim } }, "BLOCK 280,481,203"))), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", borderBottom: `1px solid ${T.border}`, flexShrink: 0 } }, /* @__PURE__ */ React.createElement(MeshHero, { znodes: MOCK_ZNODES }), /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", bottom: 0, left: 0, right: 0, display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 1, background: "rgba(8,8,10,0.85)", backdropFilter: "blur(12px)", borderTop: `1px solid ${T.border}` } }, [
    { label: "TVL", value: "$12.4M", change: "+2.3%", spark: _sparkTVL },
    { label: "PIPELINES", value: "48,291", change: "+847", spark: _sparkPipe },
    { label: "POSEIDON COMMITS", value: "14,820", change: "+312", spark: _sparkPos, color: T.cyan },
    { label: "ZNODES", value: "28 / 32" },
    { label: "AVG LATENCY", value: "34ms", change: "-3ms", spark: _sparkLat, color: T.cyan },
    { label: "MERCHANTS", value: "12", change: "+2" }
  ].map((s, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { borderRight: i < 5 ? `1px solid ${T.border}` : "none" } }, /* @__PURE__ */ React.createElement(StatCard, { ...s, sparkData: s.spark })))), /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", top: 20, left: 28, pointerEvents: "none" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.2em", marginBottom: 6 } }, "MESH TOPOLOGY"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontSize: 32, color: T.text, fontStyle: "italic", opacity: 0.6 } }, "Live Network"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 340px", flex: 1, minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { borderRight: `1px solid ${T.border}`, display: "flex", flexDirection: "column", minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 24px 0", flexShrink: 0 } }, /* @__PURE__ */ React.createElement(SearchBar, { value: search, onChange: setSearch }), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 14 } }, /* @__PURE__ */ React.createElement(Tabs, { tabs, active: tab, onChange: setTab }))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto", padding: "0 24px 24px" } }, tab === "pipelines" && /* @__PURE__ */ React.createElement(ExPipelinesView, { data: MOCK_PIPELINES, search, onSelect: setSel }), tab === "poseidon" && /* @__PURE__ */ React.createElement(PoseidonView, { data: MOCK_POSEIDON, search, onSelect: setSel }), tab === "agents" && /* @__PURE__ */ React.createElement(AgentsRichView, { data: MOCK_AGENTS_V2, search, onSelect: setSel }), tab === "merchants" && /* @__PURE__ */ React.createElement(MerchantsView, { data: MOCK_MERCHANTS, search, onSelect: setSel }), tab === "znodes" && /* @__PURE__ */ React.createElement(ZnodesView, { data: MOCK_ZNODES, search, onSelect: setSel }))), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", padding: "16px", gap: 12, minHeight: 0 } }, /* @__PURE__ */ React.createElement(MCPPanel, null), /* @__PURE__ */ React.createElement(TelegramPanel, null))), /* @__PURE__ */ React.createElement(DetailSlide, { sel, onClose: () => setSel(null) }));
}
function CombinedApp() {
  const route = useHashRoute();
  React.useEffect(() => {
    if (route === "dapp" || route === "explorer") {
      document.body.style.overflow = "hidden";
      document.body.style.height = "100vh";
    } else {
      document.body.style.overflow = "";
      document.body.style.height = "";
      document.body.style.overflowX = "hidden";
    }
    window.scrollTo(0, 0);
  }, [route]);
  const pages = {
    home: LandingPage,
    dapp: DAppPage,
    explorer: ExplorerPage,
    architecture: ArchPage,
    docs: DocsPage,
    whitepaper: WhitepaperPage,
    why: WhyPage,
    changelog: ChangelogPage
  };
  const Page = pages[route] || LandingPage;
  return /* @__PURE__ */ React.createElement(Page, { key: route });
}
ReactDOM.createRoot(document.getElementById("root")).render(/* @__PURE__ */ React.createElement(CombinedApp, null));
