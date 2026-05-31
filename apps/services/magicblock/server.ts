import express from "express";
import cors from "cors";
import axios from "axios";
import { 
  createSolanaRpc, 
  address, 
} from "@solana/kit";

const app = express();
const port = 8090;

app.use(cors());
app.use(express.json());

const RPC_URL = process.env.XB77_SOL_RPC_URL || "https://api.devnet.solana.com";
const SEQUENCER_URL = process.env.XB77_MAGICBLOCK_URL || "https://devnet.magicblock.app";
// When LIVE=1, the shim makes real HTTP calls to MagicBlock's devnet
// sequencer instead of returning synthetic responses. LIVE=0 (default)
// keeps deterministic behavior for CI / demo capture.
const LIVE = process.env.XB77_MAGICBLOCK_LIVE === "1";
// MagicBlock's Delegation Program on Solana (devnet + mainnet).
// CPI to this program is what makes a PER session appear on MagicBlock's
// own explorer. Our Zig L1-escrow path currently calls our own xb77 program;
// the wire to the Delegation Program is on the immediate roadmap.
const MAGICBLOCK_DELEGATION_PROGRAM = "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh";

const rpc = createSolanaRpc(RPC_URL);

app.get("/healthz", (req, res) => {
  res.json({
    ok: true,
    sequencer: SEQUENCER_URL,
    delegation_program: MAGICBLOCK_DELEGATION_PROGRAM,
    live: LIVE,
    kit_v2: true,
  });
});

app.post("/session/open", async (req, res) => {
  const { authority, amount, duration } = req.body;
  if (!authority) return res.status(400).json({ error: "Missing authority" });

  console.log(`[MAGIC] Opening PER session for ${authority} (live=${LIVE})`);

  if (LIVE) {
    // Hit the live devnet sequencer. Path/shape per MagicBlock's REST API.
    try {
      const r = await axios.post(`${SEQUENCER_URL}/session/open`, {
        authority,
        amount: amount ?? 2_000_000_000,
        duration_s: duration ?? 3600,
        delegation_program: MAGICBLOCK_DELEGATION_PROGRAM,
      }, { timeout: 8000 });
      return res.json({
        ok: true,
        live: true,
        session_id: r.data.session_id || r.data.id,
        expiry: r.data.expiry || (Date.now() + (duration || 3600) * 1000),
        sequencer: SEQUENCER_URL,
        l1_anchor_sig: r.data.l1_anchor_sig || r.data.tx_sig,
        raw: r.data,
      });
    } catch (e: any) {
      console.error("[MAGIC] live sequencer failed:", e?.response?.status, e?.message);
      return res.status(502).json({
        error: "live_sequencer_unreachable",
        details: e?.response?.data || e?.message,
        sequencer: SEQUENCER_URL,
      });
    }
  }

  // Deterministic synthetic response (LIVE=0).
  const session_id = "MB_PER_" + Math.random().toString(36).substring(7);
  res.json({
    ok: true,
    live: false,
    session_id,
    expiry: Date.now() + (duration || 3600) * 1000,
    sequencer: SEQUENCER_URL,
    l1_anchor_sig: "5K3sP9Rb2vQfNm8jX1pT4hY7wL9aE6cZ0gA77v6J5m9Xy4kZ77v6J5m9X",
  });
});

app.post("/tx/dispatch", async (req, res) => {
  const { session_id, target, amount, payload_hash, signature } = req.body;
  if (!session_id || !target) return res.status(400).json({ error: "Missing session or target" });

  console.log(`[MAGIC] Dispatching HFT Tx (session ${session_id}, live=${LIVE})`);

  if (LIVE) {
    try {
      const r = await axios.post(`${SEQUENCER_URL}/tx`, {
        session_id,
        target,
        amount,
        payload_hash,
        signature,
      }, { timeout: 5000 });
      return res.json({
        ok: true,
        live: true,
        sequencer_sig: r.data.sequencer_sig || r.data.sig,
        status: r.data.status || "accepted",
        raw: r.data,
      });
    } catch (e: any) {
      console.error("[MAGIC] live dispatch failed:", e?.response?.status, e?.message);
      return res.status(502).json({
        error: "live_dispatch_failed",
        details: e?.response?.data || e?.message,
      });
    }
  }

  res.json({
    ok: true,
    live: false,
    sequencer_sig: "EPHEM_SIG_" + Math.random().toString(36).substring(7),
    status: "accepted_in_rollup",
  });
});

app.listen(port, () => {
  console.log(`MagicBlock PER service (Kit v2) listening at http://localhost:${port}`);
});
