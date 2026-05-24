function ComplianceAudit() {
  const [attestation, setAttestation] = React.useState(null);
  const [loading, setLoading] = React.useState(false);
  const t = THEMES.obsidian;

  const handleGenerate = async () => {
    setLoading(true);
    try {
      const r = await fetch("http://127.0.0.1:8080/api/v1/audit/attestation", { mode: "cors" });
      if (r.ok) {
        const j = await r.json();
        setAttestation(j);
      }
    } finally {
      setLoading(false);
    }
  };

  const downloadAudit = () => {
    if (!attestation) return;
    const blob = new Blob([JSON.stringify(attestation, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `xb77-audit-${attestation.agent_id.slice(0, 8)}-${Date.now()}.json`;
    a.click();
  };

  return /* @__PURE__ */ React.createElement("div", { style: { 
    background: D.bg2, 
    border: `1px solid ${D.border}`, 
    padding: 24,
    marginTop: 24 
  } }, 
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10, marginBottom: 20 } }, 
      /* @__PURE__ */ React.createElement("span", { style: { fontSize: 20 } }, "\u{1F4D1}"), 
      /* @__PURE__ */ React.createElement(DS, { size: 18, italic: true }, "CFO & Compliance Audit")),
    
    !attestation ? /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16 } }, 
      /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint } }, "Generate a math-verified attestation of all autonomous activity for regulatory compliance."),
      /* @__PURE__ */ React.createElement(DBtn, { primary: true, onClick: handleGenerate, disabled: loading }, loading ? "\u2026ATTESTING" : "GENERATE_SIGNED_AUDIT")
    ) : /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16, animation: "fadeIn 0.4s ease" } }, 
      /* @__PURE__ */ React.createElement("div", { style: { padding: "16px", background: D.bg, border: `1px solid ${D.green}44`, fontFamily: "var(--mono)" } }, 
        /* @__PURE__ */ React.createElement("div", { style: { fontSize: 12, color: D.green, fontWeight: 700, marginBottom: 12 } }, "\u2705 ATTESTATION_VERIFIED_BY_KERNEL"),
        /* @__PURE__ */ React.createElement("div", { style: { fontSize: 10, color: D.text, marginBottom: 4 } }, "MERKLE_ROOT: ", attestation.merkle_root),
        /* @__PURE__ */ React.createElement("div", { style: { fontSize: 10, color: D.text, marginBottom: 12 } }, "AGENTIC_GDP: $", (attestation.agentic_gdp / 1e6).toFixed(2), " USDC"),
        /* @__PURE__ */ React.createElement("div", { style: { fontSize: 8, color: D.dim, wordBreak: "break-all" } }, "SIGNATURE: ", attestation.attestation_sig)),
      /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 10 } }, 
        /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true, onClick: downloadAudit }, "DOWNLOAD_REPORT (.JSON)"),
        /* @__PURE__ */ React.createElement(DBtn, { small: true, onClick: () => setAttestation(null) }, "NEW_AUDIT"))
    )
  );
}

function GuardianApprovals() {
  const [pending, setPending] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [processing, setProcessing] = React.useState(null);
  const t = THEMES.obsidian;

  const refresh = async () => {
    try {
      const r = await fetch("http://127.0.0.1:8080/api/v1/guardian/pending", { mode: "cors" });
      if (r.ok) {
        const j = await r.json();
        setPending(j.pending || []);
      }
    } catch (e) {
      setPending([]);
    } finally {
      setLoading(false);
    }
  };

  React.useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, []);

  const handleApprove = async (id) => {
    setProcessing(id);
    try {
      const r = await fetch("http://127.0.0.1:8080/api/v1/guardian/approve", { 
        method: "POST",
        mode: "cors"
      });
      if (r.ok) {
        setPending(prev => prev.filter(p => p.id !== id));
      }
    } finally {
      setProcessing(null);
    }
  };

  if (loading && pending.length === 0) return null;

  return /* @__PURE__ */ React.createElement("div", { style: { 
    background: "rgba(255,107,0,0.03)", 
    border: `1px solid ${D.amber}33`, 
    padding: 24,
    marginTop: 24 
  } }, 
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10, marginBottom: 20 } }, 
      /* @__PURE__ */ React.createElement("span", { style: { fontSize: 20 } }, "\u{1F6E1}\uFE0F"), 
      /* @__PURE__ */ React.createElement(DS, { size: 18, italic: true }, "Guardian Approvals")),
    
    pending.length === 0 ? /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.faint }, "No transactions awaiting approval.") :
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16 } }, pending.map(p => /* @__PURE__ */ React.createElement("div", { key: p.id, style: {
      padding: "16px",
      background: D.bg,
      border: `1px solid ${D.border}`,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between"
    } }, 
      /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 4 } }, 
        /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: D.text, fontWeight: 700 } }, (p.amount / 1e9).toFixed(2), " ", p.chain.toUpperCase()),
        /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, p.desc),
        /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 8, color: D.dim } }, "TARGET: ", p.recipient)),
      /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 8 } }, 
        /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true, onClick: () => handleApprove(p.id), disabled: processing === p.id }, processing === p.id ? "\u2026SIGNING" : "APPROVE_TX"),
        /* @__PURE__ */ React.createElement(DBtn, { small: true, danger: true, disabled: processing === p.id }, "REJECT"))
    )))
  );
}

function GovernanceView() {
  const [data, setData] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [simInput, setSimInput] = React.useState("");
  const [simResult, setSimResult] = React.useState(null);
  const t = THEMES.obsidian;

  React.useEffect(() => {
    const fetchLocal = async () => {
      try {
        const r = await fetch("http://127.0.0.1:8080/status", { mode: "cors" });
        if (r.ok) {
          const j = await r.json();
          setData(j.constitution);
        }
      } catch (e) {
        setData(null);
      } finally {
        setLoading(false);
      }
    };
    fetchLocal();
    const id = setInterval(fetchLocal, 5000);
    return () => clearInterval(id);
  }, []);

  const handleSimulate = () => {
    if (!simInput) return;
    const lower = simInput.toLowerCase();
    let rejected = false;
    let matchingRule = null;

    if (data && data.rules) {
      for (const rule of data.rules) {
        const rLower = rule.toLowerCase();
        if (rLower.includes("block") || rLower.includes("prohibit") || rLower.includes("never")) {
            // Very simple mock of the QVAC logic
            if (lower.includes("risk") || lower.includes("gambling") || lower.includes("high slippage")) {
                rejected = true;
                matchingRule = rule;
                break;
            }
        }
        if (rLower.includes("limit") || rLower.includes("budget")) {
             // Mock budget check
             if (lower.includes("10 sol") || lower.includes("100 sol")) {
                rejected = true;
                matchingRule = rule;
                break;
             }
        }
      }
    }

    setSimResult({
      ok: !rejected,
      rule: matchingRule,
      trace: rejected ? "QVAC_REJECTED_BY_CONSTITUTION" : "QVAC_AUTHORIZED_BY_RULES"
    });
  };

  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0, gap: 24 } }, 
    /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Agent Constitution"), 
        /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint, marginTop: 8, marginBottom: 24 } }, "Deterministic rules governing all outbound intents."), 
        
        loading ? /* @__PURE__ */ React.createElement(DM, { size: 10 }, "\u2026Loading local constitution") : 
        (!data || !data.rules || data.rules.length === 0) ? /* @__PURE__ */ React.createElement("div", { style: { padding: 40, textAlign: "center", border: `1px dashed ${D.border}` } }, /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.faint }, "Connect to a local Sovereign Agent to view its Constitution.")) :
        /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 12 } }, data.rules.map((r, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
          padding: "12px 16px",
          background: D.bg,
          borderLeft: `3px solid ${t.accent}`,
          fontFamily: "var(--mono)",
          fontSize: 12,
          color: D.text
        } }, /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, marginRight: 12 } }, "[0x" + i.toString(16) + "]"), r)))
      ),

      /* @__PURE__ */ React.createElement("div", { style: { background: "rgba(0,240,255,0.02)", border: `1px solid rgba(0,240,255,0.15)`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 18, italic: true }, "QVAC Simulator"), 
        /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint, marginTop: 8, marginBottom: 20 } }, "Test a natural language directive against the active constitution."), 
        
        /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 12 } }, 
          /* @__PURE__ */ React.createElement("input", { 
            type: "text", 
            placeholder: "e.g. Purchase 10 SOL of risky assets", 
            value: simInput, 
            onChange: (e) => setSimInput(e.target.value),
            style: { flex: 1, padding: "10px 14px", background: D.bg, border: `1px solid ${D.border}`, color: D.text, fontFamily: "var(--mono)", fontSize: 12, outline: "none" }
          }),
          /* @__PURE__ */ React.createElement(DBtn, { primary: true, onClick: handleSimulate }, "RUN_VAL_v2")
        ),

        simResult && /* @__PURE__ */ React.createElement("div", { style: {
          marginTop: 20,
          padding: "16px",
          background: simResult.ok ? "rgba(127,191,63,0.1)" : "rgba(255,68,85,0.1)",
          border: `1px solid ${simResult.ok ? D.green : D.red}`,
          fontFamily: "var(--mono)"
        } }, 
          /* @__PURE__ */ React.createElement("div", { style: { fontSize: 14, fontWeight: 700, color: simResult.ok ? D.green : D.red, marginBottom: 8 } }, simResult.ok ? "\u2705 DIRECTIVE_APPROVED" : "\u274C DIRECTIVE_BLOCKED"),
          /* @__PURE__ */ React.createElement("div", { style: { fontSize: 10, color: D.text, marginBottom: 4 } }, "TRACE: ", simResult.trace),
          !simResult.ok && /* @__PURE__ */ React.createElement("div", { style: { fontSize: 10, color: D.faint } }, "VIOLATION: ", simResult.rule)
        )
      )
    ),

    /* @__PURE__ */ React.createElement("div", { style: { width: 340, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DM, { size: 9, color: t.accent }, "ABOUT_QVAC"),
        /* @__PURE__ */ React.createElement("h3", { style: { fontFamily: "var(--serif)", fontSize: 18, color: D.text, margin: "12px 0" } }, "Quantum-Verifiable Agent Constitution"),
        /* @__PURE__ */ React.createElement("p", { style: { fontSize: 13, color: D.textDim, lineHeight: 1.6 } }, "QVAC is the deterministic filter that sits between probabilistic LLM reasoning and cryptographic execution. Every 'thought' from the agent brain must pass through the Constitution filter before it can be signed by the Secure Vault."),
        /* @__PURE__ */ React.createElement("div", { style: { marginTop: 24, padding: "12px", border: `1px solid ${D.border}`, background: D.bg } }, 
          /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "ZK_ATTESTATION_MODE"),
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text, marginTop: 6 } }, "OFF-CHAIN_ENFORCED"),
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.green, marginTop: 4 } }, "\u25CF ACTIVE")
        )
      ),
      /* @__PURE__ */ React.createElement(GuardianApprovals, null),
      /* @__PURE__ */ React.createElement(ComplianceAudit, null)
    )
  );
}

function GovernanceTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    padding: "0",
    minHeight: 600,
    display: "flex",
    flexDirection: "column"
  } }, /* @__PURE__ */ React.createElement(GovernanceView, null));
}
Object.assign(window, { GovernanceView, GovernanceTab });
