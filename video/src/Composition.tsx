import React from "react";
import { AbsoluteFill, Sequence, useCurrentFrame } from "remotion";
import { parseEvents } from "./data/parseEvents";
import type {
  AgentInitEvent,
  TradeEvent,
  MissionEvent,
  ZKVerifyEvent,
  XChainBridgeEvent,
  AnchorEvent,
} from "./data/parseEvents";
import { AgentNetwork } from "./scenes/AgentNetwork";
import { ZKVerify } from "./scenes/ZKVerify";
import { CrossChain } from "./scenes/CrossChain";
import { Anchor } from "./scenes/Anchor";

// Scene timing (frames @ 30fps)
// 0–600    AgentNetwork  (20s)
// 600–1000 ZKVerify      (13.3s)
// 1000–1200 CrossChain   (6.7s)
// 1200–1800 Anchor       (20s)

export const XB77Composition: React.FC = () => {
  const events = parseEvents();

  const zkVerifyEvents = events.filter((e): e is ZKVerifyEvent => e.type === "zk_verify");
  const xchainEvents = events.filter((e): e is XChainBridgeEvent => e.type === "xchain_bridge");
  const anchorEvents = events.filter((e): e is AnchorEvent => e.type === "anchor");

  return (
    <AbsoluteFill style={{ background: "#000000" }}>
      <Sequence from={0} durationInFrames={600}>
        <AgentNetwork events={events} />
      </Sequence>

      <Sequence from={600} durationInFrames={400}>
        <ZKVerify events={zkVerifyEvents} />
      </Sequence>

      <Sequence from={1000} durationInFrames={200}>
        <CrossChain events={xchainEvents} />
      </Sequence>

      <Sequence from={1200} durationInFrames={600}>
        <Anchor events={anchorEvents} />
      </Sequence>
    </AbsoluteFill>
  );
};
