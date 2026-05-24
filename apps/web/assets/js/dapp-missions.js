function MissionsView() {
  const [missions, setMissions] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const t = THEMES.obsidian;

  const refresh = async () => {
    try {
      const r = await fetch("http://127.0.0.1:8080/api/v1/missions/active", { mode: "cors" });
      if (r.ok) {
        const j = await r.json();
        setMissions(j.missions || []);
      }
    } catch (e) {
      setMissions([]);
    } finally {
      setLoading(false);
    }
  };

  React.useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, []);

  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0, gap: 24 } }, 
    /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Swarm Mission Control"),
        /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint, margin: "8px 0 24px" } }, "High-level goal decomposition and collaborative swarm execution."),
        
        missions.length === 0 ? /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.faint }, "No active missions. Issue one via 'xb77 issue'.") :
        missions.map(m => /* @__PURE__ */ React.createElement("div", { key: m.id, style: {
          background: D.bg,
          border: `1px solid ${D.border}`,
          padding: "24px",
          marginBottom: 20
        } }, 
          /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 20 } }, 
            /* @__PURE__ */ React.createElement("div", null, 
              /* @__PURE__ */ React.createElement(Badge, { color: D.green }, "ACTIVE"),
              /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontSize: 24, color: D.text, fontStyle: "italic", marginTop: 8 } }, m.goal)),
            /* @__PURE__ */ React.createElement("div", { style: { textAlign: "right" } }, 
              /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "PROGRESS"),
              /* @__PURE__ */ React.createElement("div", { style: { fontSize: 20, fontFamily: "var(--mono)", color: t.accent } }, m.progress, "%"))),
          
          /* @__PURE__ */ React.createElement("div", { style: { height: 4, background: D.border, borderRadius: 2, overflow: "hidden", marginBottom: 24 } }, 
            /* @__PURE__ */ React.createElement("div", { style: { width: `${m.progress}%`, height: "100%", background: t.accent, transition: "width 1s ease" } })),
          
          /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 16 } }, m.agents.map(ag => /* @__PURE__ */ React.createElement("div", { key: ag.id, style: {
            padding: "16px",
            background: D.bg2,
            border: `1px solid ${D.border}`,
            position: "relative"
          } }, 
            /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, marginBottom: 8 } }, 
               /* @__PURE__ */ React.createElement("div", { className: "xb-pulse-dot", style: { width: 6, height: 6, background: t.accent, borderRadius: "50%" } }),
               /* @__PURE__ */ React.createElement(DM, { size: 9, bold: true }, ag.role)),
            /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.text, marginBottom: 4 } }, ag.id),
            /* @__PURE__ */ React.createElement("div", { style: { fontSize: 9, color: D.faint } }, ag.status))))
        ))
      )
    ),

    /* @__PURE__ */ React.createElement("div", { style: { width: 340, background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
      /* @__PURE__ */ React.createElement(DS, { size: 14, italic: true }, "Swarm Intelligence"),
      /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16, display: "flex", flexDirection: "column", gap: 16 } }, 
        /* @__PURE__ */ React.createElement("div", null, 
          /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "ORCHESTRATION_LOG"),
          /* @__PURE__ */ React.createElement("div", { style: { marginTop: 10, fontFamily: "var(--mono)", fontSize: 9, color: D.text, lineHeight: 1.6 } }, 
            "> Decomposing objective...\n> Assigned ag_solana_01 as RECON\n> Assigned ag_base_04 as EXECUTOR\n> AWP Handshake established.\n> Constitution check passed (5/5)."))
      ))
  );
}

function MissionsTab() {
  return /* @__PURE__ */ React.createElement("div", { style: { padding: "0", minHeight: 600, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement(MissionsView, null));
}
Object.assign(window, { MissionsView, MissionsTab });
