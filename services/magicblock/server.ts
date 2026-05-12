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

const rpc = createSolanaRpc(RPC_URL);

app.get("/healthz", (req, res) => {
  res.json({ 
    ok: true, 
    sequencer: SEQUENCER_URL, 
    kit_v2: true 
  });
});

app.post("/session/open", async (req, res) => {
  const { authority, amount, duration } = req.body;
  if (!authority) return res.status(400).json({ error: "Missing authority" });

  try {
    console.log(`[MAGIC] Opening PER session for ${authority} via MagicBlock Sequencer...`);
    
    // In a real implementation with @solana/kit v2, we would:
    // 1. Build the delegation transaction using the modular functional API.
    // 2. Send the transaction to the Solana L1.
    // 3. Register the session with the sequencer via HTTP.
    
    // Mocking the result for the TS baseline
    const session_id = "MB_PER_" + Math.random().toString(36).substring(7);
    
    res.json({
        ok: true,
        session_id,
        expiry: Date.now() + (duration || 3600) * 1000,
        sequencer: SEQUENCER_URL,
        l1_anchor_sig: "5K3sP9Rb2vQfNm8jX1pT4hY7wL9aE6cZ0gA77v6J5m9Xy4kZ77v6J5m9X"
    });
  } catch (e: any) {
    res.status(500).json({ error: "Failed to open session", details: e.message });
  }
});

app.post("/tx/dispatch", async (req, res) => {
    const { session_id, target, amount, payload_hash, signature } = req.body;
    if (!session_id || !target) return res.status(400).json({ error: "Missing session or target" });

    try {
        console.log(`[MAGIC] Dispatching HFT Tx to ${SEQUENCER_URL} for session ${session_id}...`);
        
        // Use axios to hit the MagicBlock sequencer's REST API
        // const response = await axios.post(`${SEQUENCER_URL}/tx`, { ... });
        
        res.json({
            ok: true,
            sequencer_sig: "EPHEM_SIG_" + Math.random().toString(36).substring(7),
            status: "accepted_in_rollup"
        });
    } catch (e: any) {
        res.status(500).json({ error: "Dispatch failed", details: e.message });
    }
});

app.listen(port, () => {
  console.log(`MagicBlock PER service (Kit v2) listening at http://localhost:${port}`);
});
