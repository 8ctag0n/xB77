# xB77 System Architecture and Data Flow

## 1. High-Level Treasury Flow
This diagram illustrates how liquidity moves from public sources to shielded operations and yield optimization.

```mermaid
graph TD
    A[Public Source: Starpay/Vault] -->|Fund| B(xB77 Liquidity Manager)
    B -->|Check Thresholds| C{Strategic Decision}
    C -->|Idle Capital| D[Yield Provider: Kamino]
    C -->|Operational Need| E[Private Rail: ShadowWire]
    D -->|Interest Accrual| B
    E -->|B2B Payment| F[Merchant/Vendor]
    F -->|Proof Generation| G[Certified Receipt Store]
```

## 2. Autonomous Decision Loop (Strategy Engine)
The process an agent follows before executing any financial instruction.

```mermaid
graph LR
    Start[Trigger: Payment Request] --> Risk[Helius & Range Screening]
    Risk --> Score{Risk Score}
    Score -->|Low| Public[Public Route: Starpay]
    Score -->|Medium| Shield[Shielded Route: ShadowWire]
    Score -->|High| Ghost[Ghost Mode: Burner Relay]
    Score -->|Sanctioned| Block[Block Transaction]
    
    Public --> Audit[Generate Certified Receipt]
    Shield --> Audit
    Ghost --> Audit
```

## 3. Certified Selective Disclosure (Auditory)
How the agent proves its expenses to an external auditor without compromising global privacy.

```mermaid
sequenceDiagram
    participant Auditor as External Auditor
    participant Hub as Hub UI
    participant Agent as xB77 Agent
    participant Store as Private Receipt Store

    Auditor->>Hub: Request Proof for INV-001
    Hub->>Agent: Call agent.audit.report(receiptId)
    Agent->>Store: Retrieve full private receipt
    Agent->>Agent: Extract requested fields
    Agent->>Agent: Sign fields with Secret Key
    Agent-->>Hub: Certified Proof + Attestation
    Hub-->>Auditor: Display Verifiable Invoice
```

## 4. Multi-Agent Ecosystem (MCP)
The relationship between humans, infrastructure, and autonomous agents.

```mermaid
graph TD
    User[Human User] -->|Management| Hub[Hub Dashboard]
    Hub -->|Control Plane| Listener[Listener Node]
    Listener -->|Index/Sync| DB[(Global State DB)]
    
    AgentA[Agent Alpha] <-->|MCP Protocol| Listener
    AgentB[Agent Bravo] <-->|MCP Protocol| Listener
    
    AgentA -->|On-Chain| Solana[Solana Blockchain]
    AgentB -->|On-Chain| Solana
```
