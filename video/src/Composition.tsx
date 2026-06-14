import React from "react";
import { useCurrentFrame, AbsoluteFill } from "remotion";
import { parseEvents } from "./data/parseEvents";
import type {
  Event,
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

const events = parseEvents();

export const XB77Composition: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ background: "#000000", fontFamily: "'JetBrains Mono', monospace" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');`}</style>
      {frame < 600 && <AgentNetwork events={events} />}
      {frame >= 600 && frame < 1000 && <ZKVerify events={events} />}
      {frame >= 1000 && frame < 1200 && <CrossChain events={events} />}
      {frame >= 1200 && <Anchor events={events} />}
    </AbsoluteFill>
  );
};
