import React from "react";
import { useCurrentFrame, AbsoluteFill, interpolate, spring } from "remotion";
import type { Event, TradeEvent, MissionEvent, AgentInitEvent } from "../data/parseEvents";
import { AgentNode } from "../components/AgentNode";
import { TxArrow } from "../components/TxArrow";

interface AgentNetworkProps {
  events: Event[];
}

const AGENT_POSITIONS: Record<string, { x: number; y: number }> = {
  cybercore: { x: 560, y: 340 },
  shadowfin: { x: 1360, y: 340 },
  ironvault: { x: 560, y: 740 },
  neonpulse: { x: 1360, y: 740 },
};

const AGENT_COLORS: Record<string, string> = {
  cybercore: "#00ffff",
  shadowfin: "#ff00ff",
  ironvault: "#00ff88",
  neonpulse: "#ffaa00",
};

const AGENT_START_FRAMES: Record<string, number> = {
  cybercore: 0,
  shadowfin: 15,
  ironvault: 30,
  neonpulse: 45,
};

export const AgentNetwork: React.FC<AgentNetworkProps> = ({ events }) => {
  const frame = useCurrentFrame();

  const tradeEvents = events.filter((e): e is TradeEvent => e.type === "trade");
  const missionEvents = events.filter((e): e is MissionEvent => e.type === "mission");

  // Compute mission text per agent (show when t*30 <= frame)
  const agentMissions: Record<string, string> = {};
  for (const m of missionEvents) {
    if (m.t * 30 <= frame) {
      agentMissions[m.agent] = m.text;
    }
  }

  // Compute pulse per agent based on recent trade activity
  const agentPulse: Record<string, number> = {
    cybercore: 0,
    shadowfin: 0,
    ironvault: 0,
    neonpulse: 0,
  };

  for (const trade of tradeEvents) {
    const tradeStartFrame = trade.t * 30;
    const tradeEndFrame = tradeStartFrame + 60;
    if (frame >= tradeStartFrame && frame <= tradeEndFrame) {
      const progress = (frame - tradeStartFrame) / 60;
      const pulse = Math.sin(progress * Math.PI);
      agentPulse[trade.from] = Math.max(agentPulse[trade.from], pulse);
      agentPulse[trade.to] = Math.max(agentPulse[trade.to], pulse * 0.5);
    }
  }

  // Title animation
  const titleOpacity = interpolate(frame, [0, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const titleY = interpolate(frame, [0, 40], [-20, 60], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Scanline effect
  const scanlineY = ((frame * 3) % 1080);

  return (
    <AbsoluteFill style={{ background: "#000000" }}>
      <svg
        width={1920}
        height={1080}
        viewBox="0 0 1920 1080"
        style={{ position: "absolute", top: 0, left: 0 }}
      >
        {/* Grid background */}
        <defs>
          <pattern id="grid" width={60} height={60} patternUnits="userSpaceOnUse">
            <path d="M 60 0 L 0 0 0 60" fill="none" stroke="#111122" strokeWidth={0.5} />
          </pattern>
          <radialGradient id="centerGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#001133" stopOpacity={0.5} />
            <stop offset="100%" stopColor="#000000" stopOpacity={0} />
          </radialGradient>
        </defs>

        <rect width={1920} height={1080} fill="url(#grid)" />
        <rect width={1920} height={1080} fill="url(#centerGlow)" />

        {/* Scanline */}
        <rect x={0} y={scanlineY} width={1920} height={2} fill="#00ffff" opacity={0.03} />

        {/* Corner decorations */}
        <g opacity={0.4}>
          <line x1={0} y1={0} x2={60} y2={0} stroke="#00ffff" strokeWidth={1} />
          <line x1={0} y1={0} x2={0} y2={60} stroke="#00ffff" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1860} y2={0} stroke="#00ffff" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1920} y2={60} stroke="#00ffff" strokeWidth={1} />
          <line x1={0} y1={1080} x2={60} y2={1080} stroke="#00ffff" strokeWidth={1} />
          <line x1={0} y1={1080} x2={0} y2={1020} stroke="#00ffff" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1860} y2={1080} stroke="#00ffff" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1920} y2={1020} stroke="#00ffff" strokeWidth={1} />
        </g>

        {/* Static connecting lines between nodes */}
        {Object.entries(AGENT_POSITIONS).map(([a1, p1]) =>
          Object.entries(AGENT_POSITIONS)
            .filter(([a2]) => a2 > a1)
            .map(([a2, p2]) => (
              <line
                key={`${a1}-${a2}`}
                x1={p1.x}
                y1={p1.y}
                x2={p2.x}
                y2={p2.y}
                stroke="#113366"
                strokeWidth={0.8}
                opacity={0.3}
                strokeDasharray="4 8"
              />
            ))
        )}

        {/* Trade arrows */}
        {tradeEvents.map((trade, i) => {
          const fromPos = AGENT_POSITIONS[trade.from];
          const toPos = AGENT_POSITIONS[trade.to];
          if (!fromPos || !toPos) return null;

          const startFrame = trade.t * 30;
          const endFrame = startFrame + 60;
          const progress = interpolate(frame, [startFrame, endFrame], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });

          if (progress <= 0 || progress >= 1) return null;

          const color = AGENT_COLORS[trade.from] ?? "#ffffff";

          // Offset the arrow slightly so overlapping trades are visible
          const offsetX = (i % 3 - 1) * 6;
          const offsetY = (i % 2 === 0 ? 1 : -1) * 6;

          return (
            <TxArrow
              key={`trade-${i}`}
              x1={fromPos.x + offsetX}
              y1={fromPos.y + offsetY}
              x2={toPos.x + offsetX}
              y2={toPos.y + offsetY}
              color={color}
              progress={progress}
              token={trade.token}
              amount={trade.amount}
            />
          );
        })}

        {/* Agent nodes */}
        {Object.entries(AGENT_POSITIONS).map(([agent, pos]) => (
          <AgentNode
            key={agent}
            x={pos.x}
            y={pos.y}
            color={AGENT_COLORS[agent] ?? "#ffffff"}
            name={agent.toUpperCase()}
            pulse={agentPulse[agent] ?? 0}
            startFrame={AGENT_START_FRAMES[agent] ?? 0}
            missionText={agentMissions[agent]}
          />
        ))}

        {/* Title */}
        <g opacity={titleOpacity} transform={`translate(0, ${titleY - 60})`}>
          <text
            x={960}
            y={60}
            textAnchor="middle"
            fill="#00ffff"
            fontSize={42}
            fontFamily="'JetBrains Mono', 'Fira Code', monospace"
            fontWeight="700"
            letterSpacing={4}
            style={{ filter: "drop-shadow(0 0 12px #00ffff) drop-shadow(0 0 30px #00ffff80)" }}
          >
            xB77 — Agent Swarm
          </text>
          <text
            x={960}
            y={92}
            textAnchor="middle"
            fill="#888888"
            fontSize={16}
            fontFamily="'JetBrains Mono', 'Fira Code', monospace"
            letterSpacing={3}
          >
            AWP Protocol — Multi-Agent Coordination
          </text>
        </g>

        {/* Frame counter */}
        <text
          x={1880}
          y={1060}
          textAnchor="end"
          fill="#333333"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          {String(frame).padStart(4, "0")} / 0599
        </text>

        {/* Trade counter */}
        <text
          x={40}
          y={1060}
          fill="#444444"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          TRADES: {tradeEvents.filter((t) => t.t * 30 <= frame).length} / {tradeEvents.length}
        </text>
      </svg>
    </AbsoluteFill>
  );
};
