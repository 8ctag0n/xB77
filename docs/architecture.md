# // ARCHITECTURE

xB77 is a three-layer stack: agent logic at the top, a ZK proof engine in the middle, and Solana settlement at the base. Each layer communicates through well-defined interfaces with no hidden coupling.

## System Layers

```mermaid
graph TD
    subgraph SL["// SOVEREIGN LAYER — Agent Logic"]
        direction LR
        A1["Agent Brain\n(Zig / QVAC)"]
        A2["AWP Mesh\n(TCP P2P)"]
        A3["SovereignPortal\n(HTTP :8081)"]
        A1 <--> A2
        A1 --> A3
    end

    subgraph PL["// PRIVACY LAYER — ZK Engine"]
        direction LR
        B1["Noir Circuit\n(agent_badge / cmt_receipt)"]
        B2["Barretenberg Prover\n(bb 0.58)"]
        B3["Proof Buffer\n(2176 B — UltraPlonk)"]
        B1 --> B2 --> B3
    end

    subgraph SE["// SETTLEMENT LAYER — Solana"]
        direction LR
        C1["Chunked Upload\n(PDA proof_buf)"]
        C2["xb77_zk_verifier\n(J2Q44...)"]
        C3["xb77_core\nAnchorStateZk"]
        C4["Solana L1\n(Agave 3.1.14)"]
        C1 --> C2 --> C3 --> C4
    end

    SL -->|"CMT + intent"| PL
    PL -->|"zk_receipt.proof"| SE

    style SL fill:#0e0e12,stroke:#c8ff2e,stroke-width:2px,color:#c8ff2e
    style PL fill:#0e0e12,stroke:#00f0ff,stroke-width:2px,color:#00f0ff
    style SE fill:#0e0e12,stroke:#c8ff2e,stroke-width:1px,color:#c8ff2e
```

---

## Transaction Pipeline

A complete sovereign transaction flows through six discrete stages, from agent intent to on-chain finality.

```mermaid
sequenceDiagram
    participant AG as Agent<br/>(Zig)
    participant ZK as ZK Engine<br/>(Noir + bb)
    participant CL as zk_client<br/>(Rust)
    participant PDA as proof_buf PDA<br/>(Solana)
    participant VF as xb77_zk_verifier<br/>(J2Q44...)
    participant CO as xb77_core<br/>(AnchorStateZk)

    AG->>ZK: CMT + transaction intent
    ZK->>ZK: noir prove (circuit: cmt_receipt)
    ZK-->>AG: zk_receipt.proof (2176 B)

    AG->>CL: submit_proof(proof_bytes, salt)
    Note over CL,PDA: proof > 1232 B tx limit<br/>chunked upload required

    loop chunk N of K
        CL->>PDA: init / write_chunk(offset, data)
    end

    CL->>VF: verify(proof_buf_pda, verifying_key)
    VF->>VF: validate structure + entropy
    VF-->>CL: [ZK-JUDGE] verdict: GREEN

    CL->>CO: CPI anchor_state_zk(proof_hash)
    CO-->>AG: on-chain state updated
```

---

## Proof Generation Flow

```mermaid
flowchart LR
    subgraph circuit["Noir Circuit"]
        I1["Private inputs\n(amount, recipient,\ntax_rate, nonce)"]
        I2["Public inputs\n(cmt_hash, epoch)"]
        NR["noir prove\n(Noir 0.36)"]
        I1 --> NR
        I2 --> NR
    end

    subgraph proving["Barretenberg Proving"]
        BB["bb prove\n(v0.58 UltraPlonk)"]
        VK["verifying_key\n(fixed per circuit)"]
        PR["zk_receipt.proof\n(2176 bytes)"]
        NR --> BB
        BB --> VK
        BB --> PR
    end

    subgraph upload["Chunked Upload (on-chain)"]
        PDA["proof_buf PDA\n[b'proof_buf', payer, salt]"]
        INI["init tx\n(allocate buffer)"]
        WR["write_chunk txs\n(N × ≤1000 B)"]
        VRF["verify tx\n(verifier reads PDA)"]
        PR --> INI --> PDA
        PDA --> WR --> VRF
    end

    style circuit fill:#0e0e12,stroke:#c8ff2e,color:#fffffa
    style proving fill:#0e0e12,stroke:#00f0ff,color:#fffffa
    style upload fill:#0e0e12,stroke:#c8ff2e,color:#fffffa
```

---

## On-Chain Programs

Four Anchor programs are deployed on Solana. Each has a fixed program ID pinned via `declare_id!()`.

| Program | Pubkey | Role |
|---|---|---|
| `xb77_core` | `73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3` | Central state, CMT anchoring, CPI hub |
| `xb77_gateway` | `4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC` | Entry point, Blink routing, merchant lookup |
| `xb77_compression` | `6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN` | State-delta compression and receipt anchoring |
| `xb77_zk_verifier` | `J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ` | Proof acceptance via chunked PDA buffer |

See [On-Chain Programs reference](/reference/programs) for full instruction sets.

---

## Protocol Limits

These are hard constraints imposed by Solana and the current ZK stack:

| Constraint | Value | Notes |
|---|---|---|
| Max transaction payload | 1232 bytes | Forces chunked proof upload |
| Proof size (UltraPlonk) | 2176 bytes | ~1.77× over tx limit → 3 chunks |
| Verifying key | ~850 bytes | Embedded in verifier program |
| Max PDA size (proof_buf) | 10 KB | Sufficient for current circuits |
| ZK prove time (local) | ~2 – 8 s | bb 0.58 on x86-64, depends on circuit depth |
| Chunk write txs | 3 – 4 | Per proof submission |

---

## Trust Model

**The current `xb77_zk_verifier` is an honest stub.** It accepts the proof bytes via the chunked PDA pattern, validates structural integrity (correct byte length, non-zero entropy), and emits `[ZK-JUDGE] verdict: GREEN`. It does **not** perform cryptographic SNARK verification against the verifying key.

This is a deliberate, documented design choice for the hackathon milestone. The full pipeline — circuit, prover, chunked transport, on-chain PDA, verifier instruction — is wired end-to-end and produces real on-chain transactions. The missing piece is the arithmetic verification inside the program.

**Planned upgrade path:**

1. Integrate a Barretenberg WASM verifier via BPF-compatible bindings, or
2. Use Solana's native ZK Token proof system once UltraPlonk is supported, or
3. Ship a custom Honk verifier program built from the Barretenberg C++ library compiled to BPF.

Timeline: post-hackathon, estimated 2 – 4 weeks engineering.

> The stub is honest. The architecture is real. The proof generation and on-chain upload work exactly as documented.

---

## Component Dependency Map

```mermaid
graph LR
    subgraph Offchain["Off-chain"]
        AG["Agent\n(Zig)"]
        GW["Gateway WASM\n(Cloudflare Workers)"]
        ZN["ZNode\n(gRPC stream)"]
        BB2["bb 0.58\n(Barretenberg)"]
        NO["Noir 0.36\n(circuit)"]
    end

    subgraph Onchain["On-chain (Solana)"]
        CORE["xb77_core"]
        VF2["xb77_zk_verifier"]
        REG["xb77_registry"]
        COMP["xb77_compression"]
    end

    AG --> GW
    AG --> ZN
    AG --> NO
    NO --> BB2
    BB2 -->|"proof bytes"| AG
    AG -->|"chunked upload"| VF2
    AG -->|"CPI"| CORE
    CORE --> COMP
    CORE --> REG

    style Offchain fill:#0a0a0e,stroke:#c8ff2e,color:#c8ff2e
    style Onchain fill:#0a0a0e,stroke:#00f0ff,color:#00f0ff
```

---

## Related Documentation

- [Whitepaper](/whitepaper) — protocol design rationale and ZK system analysis
- [Deploy Guide](/guide/deploy) — how to deploy all four programs to devnet
- [On-Chain Programs](/reference/programs) — instruction-level reference
- [Proof Format](/reference/proof-format) — byte layout, chunking protocol, PDA derivation
