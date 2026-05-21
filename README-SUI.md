# 🌊 xB77 Sui Edition — *The Sovereign Agentic OS*

> **Sui Overflow 2026 Submission**  
> **Track:** Agentic Web  
> **Tagline:** xB77 now speaks Move. Sovereign treasury objects, PTB-composed agent actions, and Ghost Receipts on Sui's parallel runtime.

## 1. Why Sui is the Home of Sovereign Agents

In legacy blockchains, AI agents are just scripts holding private keys. On Sui, **The Agent is the Object**.  
xB77 leverages Sui’s object-centric model to turn agents into true, on-chain autonomous entities.

### Key Innovations:
- **Treasury Objects:** Agents own their state and capital as first-class objects (`OwnedObjects`).
- **Programmable Transaction Blocks (PTB):** xB77 packs reasoning, swapping, and auditing into a single atomic PTB. No more multi-step confirmation lag.
- **Move-Powered Constitution:** Agent spending limits and whitelists are enforced by Move's resource semantics, providing hardware-grade safety for autonomous capital.
- **Ghost Receipts on Sui:** Every agent action emits a ZK-commitment verified against Sui's high-throughput event bus.

---

## 2. Architecture: Zig Core + Move Logic

xB77 remains lean and sovereign. We use a **High-Performance Sidecar** pattern:
1.  **Zig Core:** The high-performance "Brain" and AWP (Agent Wire Protocol) engine.
2.  **Move Package (`apps/move-packages/sovereign/`):** Defines the `Treasury`, `Policy`, and `Receipt` objects.
3.  **TS Bridge (`apps/sui-bridge/`):** A lightweight Node.js shim that receives binary intents from the Zig core and builds the corresponding **PTBs** using the Sui TS SDK.

---

## 3. The "Agentic Web" Showcase

Our demo demonstrates a **Swarm Coordination** scenario:
- **Perception:** Agent detects an imbalance or a service need.
- **Reasoning:** Local QVAC Brain translates intent to a Sui-native action.
- **Execution:** A single PTB creates a new `Treasury`, deposits SUI, swaps via **Cetus**, and emits a `GhostReceipt`.
- **Parallelism:** 5+ agents executing these PTBs simultaneously, showcasing Sui’s parallel execution engine.

---

## 4. Getting Started (Sui Edition)

```bash
# Initialize a Sui-Native Agent
./zig-out/bin/xb77 init --chain sui --profile my-sui-agent

# Emit an autonomous mission to the Sui Swarm
./zig-out/bin/xb77 -p my-sui-agent issue "Optimize my treasury for yield on Navi"
```

*Sovereignty is not given, it is computed. Now on Sui.*
