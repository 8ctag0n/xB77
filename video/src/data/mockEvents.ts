import type {
  Event,
  AgentInitEvent,
  TradeEvent,
  MissionEvent,
  BatchCloseEvent,
  ZKVerifyEvent,
  XChainBridgeEvent,
  AnchorEvent,
  DoneEvent,
} from "./types";

const agentInits: AgentInitEvent[] = [
  { t: 0, type: "agent_init", agent: "cybercore", name: "CYBERCORE", color: "#00ffff" },
  { t: 0, type: "agent_init", agent: "shadowfin", name: "SHADOWFIN", color: "#ff00ff" },
  { t: 0, type: "agent_init", agent: "ironvault", name: "IRONVAULT", color: "#00ff88" },
  { t: 0, type: "agent_init", agent: "neonpulse", name: "NEONPULSE", color: "#ffaa00" },
];

const trades: TradeEvent[] = [
  {
    t: 1,
    type: "trade",
    from: "cybercore",
    to: "shadowfin",
    amount: 1200,
    token: "USDC",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000001",
    chain: "robinhood",
  },
  {
    t: 2,
    type: "trade",
    from: "shadowfin",
    to: "ironvault",
    amount: 850,
    token: "WETH",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000002",
    chain: "robinhood",
  },
  {
    t: 3,
    type: "trade",
    from: "ironvault",
    to: "neonpulse",
    amount: 3400,
    token: "USDT",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000003",
    chain: "robinhood",
  },
  {
    t: 4,
    type: "trade",
    from: "neonpulse",
    to: "cybercore",
    amount: 560,
    token: "ARB",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000004",
    chain: "arbitrum",
  },
  {
    t: 5,
    type: "trade",
    from: "cybercore",
    to: "ironvault",
    amount: 2100,
    token: "USDC",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000005",
    chain: "robinhood",
  },
  {
    t: 6,
    type: "trade",
    from: "shadowfin",
    to: "neonpulse",
    amount: 780,
    token: "WBTC",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000006",
    chain: "arbitrum",
  },
  {
    t: 8,
    type: "trade",
    from: "ironvault",
    to: "cybercore",
    amount: 4200,
    token: "USDT",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000007",
    chain: "robinhood",
  },
  {
    t: 9,
    type: "trade",
    from: "neonpulse",
    to: "shadowfin",
    amount: 990,
    token: "ETH",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000008",
    chain: "arbitrum",
  },
  {
    t: 11,
    type: "trade",
    from: "cybercore",
    to: "neonpulse",
    amount: 1750,
    token: "USDC",
    tx: "0xabc1000000000000000000000000000000000000000000000000000000000009",
    chain: "robinhood",
  },
  {
    t: 13,
    type: "trade",
    from: "shadowfin",
    to: "cybercore",
    amount: 320,
    token: "ARB",
    tx: "0xabc100000000000000000000000000000000000000000000000000000000000a",
    chain: "arbitrum",
  },
  {
    t: 15,
    type: "trade",
    from: "ironvault",
    to: "shadowfin",
    amount: 6100,
    token: "USDC",
    tx: "0xabc100000000000000000000000000000000000000000000000000000000000b",
    chain: "robinhood",
  },
  {
    t: 18,
    type: "trade",
    from: "neonpulse",
    to: "ironvault",
    amount: 2250,
    token: "WETH",
    tx: "0xabc100000000000000000000000000000000000000000000000000000000000c",
    chain: "arbitrum",
  },
];

const missions: MissionEvent[] = [
  { t: 2, type: "mission", agent: "cybercore", text: "ARBITRAGE: USDC/WETH spread detected" },
  { t: 3, type: "mission", agent: "shadowfin", text: "LIQUIDITY: Rebalancing pool positions" },
  { t: 4, type: "mission", agent: "ironvault", text: "VAULT: Securing collateral ratio 150%" },
  { t: 5, type: "mission", agent: "neonpulse", text: "SIGNAL: Cross-chain momentum buy" },
];

const batchClose: BatchCloseEvent[] = [
  {
    t: 19,
    type: "batch_close",
    root: "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4",
    n_trades: 12,
    agents: ["cybercore", "shadowfin", "ironvault", "neonpulse"],
  },
];

const zkVerify: ZKVerifyEvent[] = [
  {
    t: 20,
    type: "zk_verify",
    chain: "Robinhood Chain",
    contract: "0xdeadbeef00000000000000000000000000000001",
    result: true,
    tx: "0xf1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2",
  },
  {
    t: 21,
    type: "zk_verify",
    chain: "Arbitrum Sepolia",
    contract: "0xdeadbeef00000000000000000000000000000002",
    result: true,
    tx: "0xa1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
  },
];

const xchainBridge: XChainBridgeEvent[] = [
  {
    t: 22,
    type: "xchain_bridge",
    from_chain: "Robinhood Chain",
    to_chain: "Arbitrum Sepolia",
    root: "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4",
  },
];

const anchors: AnchorEvent[] = [
  {
    t: 23,
    type: "anchor",
    chain: "Robinhood Chain",
    root: "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4",
    tx: "0xc0ffee00000000000000000000000000000000000000000000000000000000001",
    block: 4421337,
  },
  {
    t: 24,
    type: "anchor",
    chain: "Arbitrum Sepolia",
    root: "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4",
    tx: "0xc0ffee00000000000000000000000000000000000000000000000000000000002",
    block: 91823456,
  },
];

const done: DoneEvent[] = [
  {
    t: 25,
    type: "done",
    message: "xB77 Sovereign OS — ZK-Proven on Arbitrum. Batch complete.",
  },
];

export const mockEvents: Event[] = [
  ...agentInits,
  ...trades,
  ...missions,
  ...batchClose,
  ...zkVerify,
  ...xchainBridge,
  ...anchors,
  ...done,
];
