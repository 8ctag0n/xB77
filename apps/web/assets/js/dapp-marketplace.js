const STRATEGIES = [
  { id: "arb-sol-usdc", name: "L1 Arbitrage Engine", desc: "High-frequency triangular arbitrage between Orca/Raydium pools.", cost: "10 SC/tx", tier: "Premium", icon: "\u26A1" },
  { id: "yield-max", name: "Liquid Yield Stripper", desc: "Auto-compounding yield farmer for LSTs (JupSOL/msol).", cost: "5 SC/tx", tier: "Core", icon: "\u{1F331}" },
  { id: "recon-sentinel", name: "Chain Recon Monitor", desc: "Advanced mempool watching and MEV protection for the swarm.", cost: "Free", tier: "OSS", icon: "\u{1F501}" },
  { id: "institutional-loan", name: "Flash Loan Orchestrator", desc: "Multi-protocol flash loans for instant leverage events.", cost: "Premium Sub", tier: "Enterprise", icon: "\u{1F3DB}" }
];

function MarketplaceView() {
  const [credits, setCredits] = React.useState(1240);
  const [installing, setInstalling] = React.useState(null);
  const t = THEMES.obsidian;

  const handleInstall = (id) => {
    setInstalling(id);
    setTimeout(() => {
      setInstalling(null);
      setCredits(prev => prev - 100);
    }, 2000);
  };

  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0, gap: 24 } }, 
    /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 } }, STRATEGIES.map((s, i) => /* @__PURE__ */ React.createElement("div", { key: s.id, style: {
        background: D.bg2,
        border: `1px solid ${D.border}`,
        padding: "24px",
        position: "relative",
        transition: "all 0.2s"
      } }, 
        /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 12, marginBottom: 12 } }, 
          /* @__PURE__ */ React.createElement("span", { style: { fontSize: 24 } }, s.icon),
          /* @__PURE__ */ React.createElement("div", null, 
            /* @__PURE__ */ React.createElement(DS, { size: 16, bold: true }, s.name),
            /* @__PURE__ */ React.createElement(Badge, { color: s.tier === "Premium" ? D.accent : D.dim }, s.tier))),
        /* @__PURE__ */ React.createElement("p", { style: { fontSize: 12, color: D.textDim, lineHeight: 1.5, marginBottom: 20 } }, s.desc),
        /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between" } }, 
           /* @__PURE__ */ React.createElement(DM, { size: 9, color: t.accent }, "COST: ", s.cost),
           /* @__PURE__ */ React.createElement(DBtn, { primary: true, small: true, onClick: () => handleInstall(s.id), disabled: !!installing }, installing === s.id ? "\u2026INJECTING" : "INSTALL_SKILL"))
      )))
    ),

    /* @__PURE__ */ React.createElement("div", { style: { width: 340, display: "flex", flexDirection: "column", gap: 24 } }, 
       /* @__PURE__ */ React.createElement("div", { style: { background: "rgba(200,255,46,0.03)", border: `1px solid ${t.accent}33`, padding: 24 } }, 
         /* @__PURE__ */ React.createElement(DS, { size: 18, italic: true }, "Sovereign Credits"),
         /* @__PURE__ */ React.createElement("div", { style: { fontSize: 48, fontFamily: "var(--mono)", color: t.accent, margin: "16px 0" } }, credits),
         /* @__PURE__ */ React.createElement("p", { style: { fontSize: 11, color: D.faint, marginBottom: 20 } }, "Used for Edge execution, ZK-proving cycles, and Premium Strategies."),
         /* @__PURE__ */ React.createElement(DBtn, { primary: true, full: true }, "REFILL_CREDITS")),

       /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
         /* @__PURE__ */ React.createElement(DS, { size: 14, italic: true }, "Cloud Billing History"),
         /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16, display: "flex", flexDirection: "column", gap: 10 } }, [
           { item: "Fly.io Micro-VM (24/7)", cost: "-2.5 SC" },
           { item: "ZK-Batch Settlement", cost: "-0.5 SC" },
           { item: "AWP High-Frequency Bridge", cost: "-1.0 SC" }
         ].map((b, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { display: "flex", justifyContent: "space-between", borderBottom: `1px solid ${D.border}`, paddingBottom: 8 } }, 
           /* @__PURE__ */ React.createElement(DM, { size: 8 }, b.item),
           /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.red }, b.cost)
         ))))
    )
  );
}

function MarketplaceTab() {
  return /* @__PURE__ */ React.createElement("div", { style: { padding: "0", minHeight: 600, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement(MarketplaceView, null));
}
Object.assign(window, { MarketplaceView, MarketplaceTab });
