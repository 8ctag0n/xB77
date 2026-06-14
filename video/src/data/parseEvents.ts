import { mockEvents } from "./mockEvents";

export type {
  AgentInitEvent,
  TradeEvent,
  MissionEvent,
  BatchCloseEvent,
  ZKVerifyEvent,
  XChainBridgeEvent,
  AnchorEvent,
  DoneEvent,
  Event,
} from "./types";

export function parseEvents() {
  return mockEvents;
}
