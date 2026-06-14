export type AgentInitEvent = {
  t: number;
  type: "agent_init";
  agent: string;
  name: string;
  color: string;
};

export type TradeEvent = {
  t: number;
  type: "trade";
  from: string;
  to: string;
  amount: number;
  token: string;
  tx: string;
  chain: string;
};

export type MissionEvent = {
  t: number;
  type: "mission";
  agent: string;
  text: string;
};

export type BatchCloseEvent = {
  t: number;
  type: "batch_close";
  root: string;
  n_trades: number;
  agents: string[];
};

export type ZKVerifyEvent = {
  t: number;
  type: "zk_verify";
  chain: string;
  contract: string;
  result: boolean;
  tx: string;
};

export type XChainBridgeEvent = {
  t: number;
  type: "xchain_bridge";
  from_chain: string;
  to_chain: string;
  root: string;
};

export type AnchorEvent = {
  t: number;
  type: "anchor";
  chain: string;
  root: string;
  tx: string;
  block: number;
};

export type DoneEvent = {
  t: number;
  type: "done";
  message: string;
};

export type Event =
  | AgentInitEvent
  | TradeEvent
  | MissionEvent
  | BatchCloseEvent
  | ZKVerifyEvent
  | XChainBridgeEvent
  | AnchorEvent
  | DoneEvent;
