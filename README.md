# xB77: Autonomous Financial Infrastructure for AI Agents

## Sovereign Financial Operating System for Autonomous Entities
## Sistema Operativo Financiero Soberano para Entidades Autónomas

---

### Abstract / Resumen

[EN] AI Agents represent a new class of economic actors that currently face significant financial limitations. Public blockchain transparency exposes proprietary strategies and vendor relationships, while lack of legal identity prevents access to traditional banking. xB77 provides a hybrid infrastructure that enables agents to manage shielded treasuries, optimize capital through autonomous yield generation, and maintain compliance through certified selective disclosure.

[ES] Los Agentes de IA representan una nueva clase de actores económicos que actualmente enfrentan limitaciones financieras significativas. La transparencia de las redes públicas expone estrategias propietarias y relaciones con proveedores, mientras que la falta de identidad legal impide el acceso a la banca tradicional. xB77 proporciona una infraestructura híbrida que permite a los agentes gestionar tesorerías protegidas, optimizar capital mediante la generación autónoma de rendimiento y mantener el cumplimiento normativo a través de la revelación selectiva certificada.

---

### Core Components / Componentes Principales

#### 1. Shielded Treasury Management
Leveraging Light Protocol and ShadowWire to decouple agent identity from transaction history, ensuring enterprise-grade privacy for B2B operations.

#### 2. Autonomous Yield Optimization
Idle capital is dynamically allocated to lending protocols such as Kamino. This enables agents to self-fund their operational expenses, including network fees and computational costs, without external intervention.

#### 3. Certified Selective Disclosure
A Zero-Knowledge based auditing framework that allows agents to prove transaction validity (amount, date, status) to authorized entities without compromising the privacy of recipients or sensitive metadata.

#### 4. Institutional Compliance
Integrated real-time screening via Range Protocol to ensure all autonomous transactions adhere to global sanctions and risk management standards.

---

### Technical Architecture / Arquitectura Técnica

*   ZK Framework: Noir (Identity Attestation & Selective Disclosure).
*   Settlement Layer: Solana (Anchor Protocol).
*   Execution Environment: TypeScript / Bun (Agentic Financial OS).
*   Data Observability: Helius RPC & Webhooks.

---

### Devnet Deployment Status (Live Jan 28, 2026)

#### 1. On-Chain Programs (The Core)
All programs deployed and authorized by the Deployer.

| Program | Address | Role |
| :--- | :--- | :--- |
| **xB77 Core** | `FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv` | Payment Orchestrator & Credit Logic |
| **xB77 Gateway** | `4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC` | Multi-Rail Adapter (Router) |
| **xB77 Receipts** | `8iGuTTFLhNfbUN8teY6t1SEJ7vFFzVKd3bsXUhi1R12W` | ZK-Proof Storage & Verification |
| **xB77 Registry** | `8Asy6SMxj38vqz5dJb7TYCoV1RctrF88KxFu19A6DPWz` | Agent Identity Directory |
| **xB77 Test Utils** | `2cevUmfqJU8uvHvR7jbn4vrYqG2KwgytDVypueQt5Wtx` | Mock Treasury / Faucets |

#### 2. Identity & Authority
*   **Deployer/Admin/Agent:** `4uvdh823eysqVDR9e3o6st3fGWUyctZMxMK5dJ5h49dC`
*   **Role:** Protocol Owner & Active Agent
*   **Devnet Balance:** ~12 SOL

#### 3. On-Chain State (PDAs)
Initialized via `scripts/init-devnet.ts`.
*   **Global Config PDA:** `Ese5D21LUHfn2QSAtwG8KdUqQ7swxqQvcFsxeCGMKhi1`
*   **Agent Credit Line PDA:** `FRhR1XKQJpZUpNgD3qPXyPNahU8UngMvXmwafwCs7Rx5`
    *   **Status:** Active
    *   **Limit:** $5,000 USD1

#### 4. Integration Stack (The Bounties)
| Integration | Status | Role |
| :--- | :--- | :--- |
| **Helius** | **Active** | Priority Fees, Forensic Radar, ZK-RPC (via Resilience Mode) |
| **Starpay** | **Active** | Virtual Cards (Visa/Mastercard) Off-ramp |
| **ShadowWire** | **Active** | Institutional Privacy Rail (with xB77 Fallback) |
| **PrivacyCash** | **Active** | Retail Privacy Pool (with xB77 Fallback) |
| **Light Protocol** | **Active** | Native ZK-Compression (via xB77 Native Adapter) |

#### 5. Local Persistence
*   **Database:** SQLite (`xb77_agent_4uvdh...db`)
*   **Data:** Stores full receipt history, ZK audit trails, and agent metadata locally.

---

### Documentation / Documentación

*   [Operation Guide / Guía de Inicio](docs/guide/GETTING_STARTED)
*   [Technical Whitepaper (EN)](docs/whitepaper/WHITEPAPER_EN)
*   [Libro Blanco Técnico (ES)](docs/whitepaper/WHITEPAPER_ES)
*   [Architecture & Data Flow (EN)](docs/architecture/DIAGRAMS)
*   [Arquitectura y Flujo (ES)](docs/architecture/DIAGRAMS_ES)

---
Copyright (c) 2026 xB77 Labs. All rights reserved.