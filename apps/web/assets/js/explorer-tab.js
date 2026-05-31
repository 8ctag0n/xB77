const _expSparkTVL = Array.from({ length: 20 }, (_, i) => 10 + Math.sin(i * 0.4) * 3 + Math.random() * 2);
const _expSparkPipe = Array.from({ length: 20 }, (_, i) => 300 + i * 20 + Math.random() * 60);
const _expSparkLat = Array.from({ length: 20 }, (_, i) => 30 + Math.sin(i * 0.6) * 10 + Math.random() * 5);
const _expSparkPos = Array.from({ length: 20 }, (_, i) => 50 + i * 8 + Math.random() * 30);
const ExPipelinesView = window._ExPipelinesView;
function ExplorerTab() {
  const [search, setSearch] = React.useState("");
  const [tab, setTab] = React.useState("pipelines");
  const [sel, setSel] = React.useState(null);
  const [liveAgents, setLiveAgents] = React.useState(null);
  const [livePipelines, setLivePipelines] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    const unsub1 = window.DataSource.subscribe("agents", setLiveAgents, 1e4);
    const unsub2 = window.DataSource.subscribe("pipelinesRecent", setLivePipelines, 5e3);
    return () => {
      unsub1();
      unsub2();
    };
  }, []);
  const agentData = liveAgents?.agents || MOCK_AGENTS_V2;
  const pipelineData = livePipelines?.pipelines || MOCK_PIPELINES;
  const tabs = [
    { id: "pipelines", label: "Pipelines", count: pipelineData.length },
    { id: "poseidon", label: "Poseidon", count: MOCK_POSEIDON.length },
    { id: "agents", label: "Agents", count: agentData.length },
    { id: "merchants", label: "Merchants", count: MOCK_MERCHANTS.length },
    { id: "znodes", label: "Znodes", count: MOCK_ZNODES.length }
  ];
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    flexDirection: "column",
    border: "1px solid var(--border-soft)",
    background: "var(--bg)",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement("div", { style: { position: "relative", borderBottom: `1px solid ${T.border}`, flexShrink: 0 } }, /* @__PURE__ */ React.createElement(MeshHero, { znodes: MOCK_ZNODES }), /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", bottom: 0, left: 0, right: 0, display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 1, background: "var(--nav-bg)", backdropFilter: "blur(12px)", borderTop: `1px solid ${T.border}` } }, [
    { label: "TVL", value: "$12.4M", change: "+2.3%", spark: _expSparkTVL },
    { label: "PIPELINES", value: pipelineData.length.toLocaleString(), spark: _expSparkPipe },
    { label: "POSEIDON COMMITS", value: "14,820", change: "+312", spark: _expSparkPos, color: T.cyan },
    { label: "ZNODES", value: "28 / 32" },
    { label: "AVG LATENCY", value: "34ms", change: "-3ms", spark: _expSparkLat, color: T.cyan },
    { label: "MERCHANTS", value: MOCK_MERCHANTS.length.toString() }
  ].map((s, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { borderRight: i < 5 ? `1px solid ${T.border}` : "none" } }, /* @__PURE__ */ React.createElement(StatCard, { ...s, sparkData: s.spark })))), /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", top: 20, left: 28, pointerEvents: "none" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.2em", marginBottom: 6 } }, "MESH TOPOLOGY"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontSize: 24, color: T.text, fontStyle: "italic", opacity: 0.6 } }, "Live Network"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 340px", minHeight: 560 } }, /* @__PURE__ */ React.createElement("div", { style: { borderRight: `1px solid ${T.border}`, display: "flex", flexDirection: "column", minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 24px 0", flexShrink: 0 } }, /* @__PURE__ */ React.createElement(SearchBar, { value: search, onChange: setSearch }), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 14 } }, /* @__PURE__ */ React.createElement(Tabs, { tabs, active: tab, onChange: setTab }))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto", padding: "0 24px 24px" } }, tab === "pipelines" && /* @__PURE__ */ React.createElement(ExPipelinesView, { data: pipelineData, search, onSelect: setSel }), tab === "poseidon" && /* @__PURE__ */ React.createElement(PoseidonView, { data: MOCK_POSEIDON, search, onSelect: setSel }), tab === "agents" && /* @__PURE__ */ React.createElement(AgentsRichView, { data: agentData, search, onSelect: setSel }), tab === "merchants" && /* @__PURE__ */ React.createElement(MerchantsView, { data: MOCK_MERCHANTS, search, onSelect: setSel }), tab === "znodes" && /* @__PURE__ */ React.createElement(ZnodesView, { data: MOCK_ZNODES, search, onSelect: setSel }))), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", padding: "16px", gap: 12, minHeight: 0 } }, /* @__PURE__ */ React.createElement(MCPPanel, null), /* @__PURE__ */ React.createElement(TelegramPanel, null))), /* @__PURE__ */ React.createElement(DetailSlide, { sel, onClose: () => setSel(null) }));
}
window.ExplorerTab = ExplorerTab;
