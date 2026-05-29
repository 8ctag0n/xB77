# // GLOSSARY

Definitions for xB77-specific terminology and general ZK/Solana concepts used throughout the documentation.

---

## A

### Agent Wire Protocol (AWP)

xB77's P2P message protocol for autonomous agent-to-agent communication. AWP runs over TCP and uses a Kademlia-style DHT for peer discovery. Messages are typed structs: `ServiceDiscovery`, `AppQuote`, `AppHire`, `AppEscrowLock`. No central server is required — peers find each other via UDP gossip broadcast.

### AnchorStateZk

The primary on-chain state account managed by `xb77_core`. Stores the latest CMT root hash, the latest verified proof hash, the epoch counter, and the cumulative anchor count. Written by `anchor_cmt` and `anchor_state_zk` instructions.

### AWP

See [Agent Wire Protocol](#agent-wire-protocol-awp).

---

## B

### Barretenberg

The C++ cryptographic proving system developed by Aztec Labs. xB77 uses Barretenberg version 0.58 as the backend for Noir circuits. Barretenberg implements UltraPlonk (and the newer Honk variant). The CLI tool is `bb`.

### Blink Deluxe

xB77's high-fidelity integration of Solana Actions (Blinks). A Blink Deluxe is a shareable payment link with dynamic metadata: reputation-bound imagery, signed agent manifests, and multi-tier service selection. Fully compatible with [dial.to](https://dial.to).

### Brain (QVAC Brain)

The agent's decision-making module. Evaluates incoming `ServiceDiscovery` messages, decides whether to generate an `AppQuote`, and checks incoming quotes against `config.max_hire_budget`. The v2 Brain includes SNS (.sol) name detection and multilingual budget parsing.

---

## C

### CMT

See [Commitment Tree](#commitment-tree-cmt).

### Chunked Upload

The protocol for submitting a proof larger than Solana's 1232-byte transaction limit. The proof is split into sequential slices and written to a PDA buffer via multiple `write_chunk` transactions. The verifier assembles the full proof from the buffer before evaluation. See [Proof Format](/reference/proof-format).

### Commitment Tree (CMT)

An append-only Merkle tree maintained locally by each agent. Each leaf encodes one transaction intent: `Hash(amount ‖ recipient_hash ‖ tax_rate ‖ epoch ‖ nonce)`. The tree root is the public commitment anchored to Solana. N intents produce one on-chain footprint.

### cmt_core

The C library (`cmt_core.c`) implementing the Keccak-256 hashing primitive for CMT leaf and root computation. Called from Zig via FFI. Fixed bugs in the Keccak-256 implementation were a critical milestone in the Sovereign Brief session (2026-05-02).

---

## D

### declare_id!

Anchor macro that pins a Rust program to a specific on-chain address. The address is derived from the program's keypair file. Changing `declare_id!()` without redeploying with the matching keypair will cause the program to fail all transactions.

---

## E

### Epoch

A monotonically increasing counter tracked in `AnchorStateZk`. Incremented with each CMT anchor. Used to prevent replay attacks and to correlate on-chain anchors with off-chain proof batches.

### EscrowLock

An AWP message (`AppEscrowLock`) sent from a provider agent to a client agent confirming receipt of hire terms. Contains `hire_id` and `escrow_amount`. Indicates the contract is active.

---

## G

### Ghost Audit

xB77's compliance mechanism. An agent generates a ZK proof of its transaction history. A **viewing key** (not the transaction data) is shared with an authorized auditor. The auditor verifies the mathematical proof without accessing underlying amounts, counterparties, or timing. The audit is complete with zero disclosure beyond the proven facts.

### Ghost Receipt

A ZK-verified transaction receipt. Proves that a specific tax rate was applied to a transaction without revealing the amount, recipient, or agent identity. Anchored on-chain as a proof hash.

### Groth16

A ZK proof system producing very small proofs (~200 bytes). Requires a circuit-specific trusted setup. Supported natively on Solana via the ZK Token SDK. A potential future migration target for xB77 if proof size becomes a bottleneck (currently handled via chunked upload).

---

## H

### Honk

Barretenberg's newer proving backend (supersedes UltraPlonk). Produces smaller proofs and has a simpler verifier circuit. The on-chain Honk verifier is one of the candidate paths for production-grade cryptographic verification in xB77. See [Whitepaper §8](/whitepaper#8-roadmap-from-stub-to-full-verifier).

### Honest Stub

xB77's term for the current `xb77_zk_verifier` implementation. It validates proof structure and entropy but does not perform cryptographic SNARK verification. The term "honest" indicates this limitation is documented and not misrepresented. The stub emits `[ZK-JUDGE] verdict: GREEN` for structurally valid proof buffers.

---

## K

### Kademlia DHT

The distributed hash table algorithm used for peer discovery in AWP. Each agent maintains a routing table (k-buckets) of known peers, organized by XOR distance. New peers are discovered via UDP gossip broadcast.

---

## M

### MeshManager

The Zig component responsible for AWP peer discovery and routing table management. Wraps the Kademlia DHT logic and exposes `broadcastPresence()` and `addPeer()` to the agent runtime.

---

## N

### Noir

A domain-specific language for ZK circuits, developed by Aztec Labs. Syntax similar to Rust. Noir compiles circuits to ACIR (Abstract Circuit Intermediate Representation), which Barretenberg then proves. xB77 uses Noir 0.36. Circuit source: `circuits/cmt_receipt/`.

---

## P

### PDA (Program Derived Address)

A Solana account address derived deterministically from a set of seeds and a program ID. PDAs have no private key — they are controlled exclusively by their program. xB77 uses a PDA (`proof_buf`) to stage proof bytes for on-chain assembly. Derivation: `[b"proof_buf", payer, salt]` under `xb77_zk_verifier`.

### Plonk / UltraPlonk

A ZK proof system using a universal structured reference string (no circuit-specific trusted setup). Barretenberg's `UltraPlonk` backend is the current xB77 prover. Produces 2176-byte proofs for the `cmt_receipt` circuit.

### proof_buf

The PDA buffer account used in the chunked upload protocol. Allocated by `init_proof_buf`, filled by `write_chunk`, consumed by `verify`. Seeds: `[b"proof_buf", payer.key(), salt]`. Max size: 10 KB.

---

## Q

### QVAC Brain

The agent's reasoning engine (v2). Capabilities: service negotiation, SNS name resolution, budget ceiling enforcement, multilingual input parsing, decision tracing logs.

---

## S

### Salt

An 8-byte caller-chosen nonce used in PDA derivation for `proof_buf`. Allows one payer to maintain multiple concurrent proof buffers. Recommended: monotonic u64 counter or timestamp.

### SNARK

Succinct Non-interactive ARgument of Knowledge. A class of ZK proof systems. xB77 uses UltraPlonk, which is a SNARK variant.

### Sovereign Agent

An agent that controls its own keys, generates its own ZK proofs, and transacts without custodial intermediaries. The target deployment model for xB77 v2.

### SovereignPortal

The agent's local HTTP server (port 8081 by default). Exposes `/status`, `/balance`, `/proof`, and audit routes. Used for the Ghost Audit Visualizer and the merchant dashboard.

---

## V

### Verifying Key (VK)

A fixed artifact output by the Noir compile + prove pipeline. Circuit-specific. Used by the verifier to check that a proof was generated for a specific circuit with specific public parameters. Embedded in `xb77_zk_verifier` at compile time. ~850 bytes.

### Viewing Key

A data artifact (not a cryptographic key in the asymmetric sense) that allows an authorized party to decode the private inputs of a specific ZK proof. In xB77, the viewing key is a JSON object containing the transaction fields committed in the proof: `{ amount, tax_paid, recipient_pubkey }`. Without it, the on-chain proof reveals nothing.

---

## Z

### ZK-Batch

A single CMT root anchor that commits to N transaction intents. The primary scalability mechanism: N agents produce 1 on-chain transaction. The batch is closed via `xb77_compression`'s `close_batch` instruction.

### ZK Judge

The on-chain program (or colloquially, the verdict it produces) that evaluates proof buffers. The current Judge is `xb77_zk_verifier`. Its output is the log line `[ZK-JUDGE] verdict: GREEN` (or `RED`). The term "Judge" emphasizes its role as an arbiter of proof validity.

### ZNode

The Zig component that maintains a gRPC connection to a Yellowstone/Geyser Solana RPC endpoint. Subscribes to on-chain events relevant to the agent (program invocations, account changes). Enables sub-50ms reaction to on-chain transactions without polling.

---

## Related Documentation

- [Architecture](/architecture) — system overview with diagrams
- [Whitepaper](/whitepaper) — technical depth on ZK design
- [Proof Format](/reference/proof-format) — byte-level proof specification
- [On-Chain Programs](/reference/programs) — instruction sets and account layouts
