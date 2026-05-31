import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import * as http from "http";

/**
 * xB77 Sui PTB Bridge (Sidecar) — Deluxe Edition
 *
 * REST sidecar for the Zig Core. Receives binary intents and composes REAL
 * Programmable Transaction Blocks against the `sovereign` Move package:
 *   sovereign::treasury  — OwnedTreasury objects (key+store)
 *   sovereign::policy    — AdminCap / Policy (withdrawal limits)
 *   sovereign::receipt   — GhostReceipt (ZK-commitment)
 *
 * The headline showcase is an ATOMIC PTB that, in a single transaction:
 *   new_treasury() -> split SUI from gas -> deposit() -> transfer to sender.
 *
 * Port: 8089
 */

const SUI_RPC_URL = process.env.SUI_RPC_URL || "http://127.0.0.1:9100"; // Localnet
const FAUCET_URL = process.env.SUI_FAUCET_URL || "http://127.0.0.1:9123/gas";
const PACKAGE_ID = process.env.SOVEREIGN_PACKAGE_ID || "0x0";
const ADMIN_CAP = process.env.SOVEREIGN_ADMIN_CAP || "0x0";
const PORT = Number(process.env.SUI_BRIDGE_PORT || 8089);

const client = new SuiClient({ url: SUI_RPC_URL });

// ── Keypair: from env (suiprivkey1...) or ephemeral + faucet-funded ──────────
let keypair: Ed25519Keypair;
if (process.env.SUI_PRIVATE_KEY) {
    const { secretKey } = decodeSuiPrivateKey(process.env.SUI_PRIVATE_KEY);
    keypair = Ed25519Keypair.fromSecretKey(secretKey);
} else {
    keypair = new Ed25519Keypair();
}
const SENDER = keypair.toSuiAddress();

async function ensureGas(): Promise<void> {
    const { totalBalance } = await client.getBalance({ owner: SENDER });
    if (BigInt(totalBalance) >= 1_000_000_000n) return;
    console.log(`[SUI-BRIDGE] Requesting faucet gas for ${SENDER}...`);
    await fetch(FAUCET_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ FixedAmountRequest: { recipient: SENDER } }),
    }).catch((e) => console.warn("[SUI-BRIDGE] faucet failed:", e.message));
    // Give the faucet tx a moment to land.
    await new Promise((r) => setTimeout(r, 1500));
}

// ── PTB composition ──────────────────────────────────────────────────────────
function buildIntent(intent: any): Transaction {
    const tx = new Transaction();
    const amount = BigInt(intent.amount ?? 100_000_000); // default 0.1 SUI

    switch (intent.action) {
        case "transfer": {
            const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(amount)]);
            tx.transferObjects([coin], tx.pure.address(intent.to));
            break;
        }

        // Headline: atomic create-treasury + fund, all in one PTB.
        case "provision":
        case "swap_and_receipt":
        case "leverage_ptb": {
            if (PACKAGE_ID === "0x0") {
                throw new Error("SOVEREIGN_PACKAGE_ID not set — publish the package first");
            }
            const treasury = tx.moveCall({
                target: `${PACKAGE_ID}::treasury::new_treasury`,
            });
            const [funding] = tx.splitCoins(tx.gas, [tx.pure.u64(amount)]);
            tx.moveCall({
                target: `${PACKAGE_ID}::treasury::deposit`,
                arguments: [treasury, funding],
            });
            // OwnedTreasury has key+store → make it owned by the agent.
            tx.transferObjects([treasury], tx.pure.address(intent.to ?? SENDER));
            break;
        }

        // Fund an existing treasury object.
        case "deposit": {
            if (!intent.treasury) throw new Error("deposit requires intent.treasury");
            const [funding] = tx.splitCoins(tx.gas, [tx.pure.u64(amount)]);
            tx.moveCall({
                target: `${PACKAGE_ID}::treasury::deposit`,
                arguments: [tx.object(intent.treasury), funding],
            });
            break;
        }

        // Mint a spending Policy (withdrawal limit) using the AdminCap.
        case "create_policy": {
            if (ADMIN_CAP === "0x0") throw new Error("SOVEREIGN_ADMIN_CAP not set");
            const limit = BigInt(intent.limit ?? 1_000_000_000); // default 1 SUI
            const policy = tx.moveCall({
                target: `${PACKAGE_ID}::policy::create_policy`,
                arguments: [tx.object(ADMIN_CAP), tx.pure.u64(limit)],
            });
            tx.transferObjects([policy], tx.pure.address(SENDER));
            break;
        }

        // Sovereign withdrawal: verify_zk_proof -> GhostReceipt -> policy-checked
        // withdraw -> transfer to recipient, atomically in one PTB.
        case "withdraw": {
            if (!intent.treasury) throw new Error("withdraw requires intent.treasury");
            if (!intent.policy) throw new Error("withdraw requires intent.policy");
            const recipient = intent.to ?? SENDER;
            // Mock ZK proof bytes (0x42) — mirrors the simnet verifier bypass.
            const proof: number[] = intent.proof ?? [0x42];
            const publicInputs: number[] = intent.public_inputs ?? [0x42];
            tx.moveCall({
                target: `${PACKAGE_ID}::treasury::execute_withdrawal`,
                arguments: [
                    tx.object(intent.treasury),
                    tx.object(intent.policy),
                    tx.pure.u64(amount),
                    tx.pure.address(recipient),
                    tx.pure.vector("u8", proof),
                    tx.pure.vector("u8", publicInputs),
                ],
            });
            break;
        }

        default:
            throw new Error(`unknown action: ${intent.action}`);
    }
    return tx;
}

const server = http.createServer((req, res) => {
    if (req.method === "POST" && req.url === "/execute") {
        let body = "";
        req.on("data", (chunk) => (body += chunk));
        req.on("end", async () => {
            try {
                const intent = JSON.parse(body);
                console.log("[SUI-BRIDGE] Intent:", intent.action);
                await ensureGas();

                const tx = buildIntent(intent);
                tx.setSender(SENDER);

                const result = await client.signAndExecuteTransaction({
                    transaction: tx,
                    signer: keypair,
                    options: { showEffects: true, showObjectChanges: true },
                });
                // Wait until indexed so back-to-back intents see fresh object
                // versions (avoids "object unavailable for consumption" on the
                // gas coin when calls fire in rapid succession).
                await client.waitForTransaction({ digest: result.digest });

                const status = result.effects?.status?.status;
                const created = (result.objectChanges ?? [])
                    .filter((c: any) => c.type === "created")
                    .map((c: any) => ({ type: c.objectType, id: c.objectId }));

                console.log(`[SUI-BRIDGE] ${status} digest=${result.digest}`);
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ ok: status === "success", digest: result.digest, created }));
            } catch (err: any) {
                console.error("[SUI-BRIDGE] Error:", err.message);
                // 200 (don't crash the Zig core) but honest — no fake digest.
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ ok: false, error: err.message }));
            }
        });
    } else if (req.method === "GET" && req.url === "/health") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, sender: SENDER, package: PACKAGE_ID, rpc: SUI_RPC_URL }));
    } else {
        res.writeHead(404);
        res.end();
    }
});

server.listen(PORT, () => {
    console.log(`[SUI-BRIDGE] Sovereign PTB Sidecar active on port ${PORT}`);
    console.log(`[SUI-BRIDGE] RPC:     ${SUI_RPC_URL}`);
    console.log(`[SUI-BRIDGE] Package: ${PACKAGE_ID}`);
    console.log(`[SUI-BRIDGE] Sender:  ${SENDER}`);
});
