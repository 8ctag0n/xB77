import React from "react";
import { useCurrentFrame, AbsoluteFill, interpolate, spring } from "remotion";
import type { Event, AnchorEvent } from "../data/parseEvents";
import { DataPulse } from "../components/DataPulse";

interface AnchorProps {
  events: Event[];
}

const SCENE_START = 1200;
const ROOT_HASH = "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4";

function truncateTx(tx: string): string {
  return `${tx.slice(0, 14)}...${tx.slice(-8)}`;
}

interface AnchorPanelProps {
  event: AnchorEvent;
  localFrame: number;
  panelStartFrame: number;
  panelX: number;
  panelY: number;
  color: string;
}

const AnchorPanel: React.FC<AnchorPanelProps> = ({
  event,
  localFrame,
  panelStartFrame,
  panelX,
  panelY,
  color,
}) => {
  const pf = Math.max(0, localFrame - panelStartFrame);

  const panelOpacity = interpolate(pf, [0, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const slideY = interpolate(pf, [0, 30], [30, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const checkScale = spring({
    frame: Math.max(0, pf - 20),
    fps: 30,
    config: { damping: 10, stiffness: 90, mass: 0.9 },
  });

  const detailsOpacity = interpolate(pf, [30, 55], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const panelW = 720;
  const panelH = 280;
  const cornerSize = 14;
  const adjustedY = panelY + slideY;

  const clipPath = [
    `${panelX + cornerSize},${adjustedY}`,
    `${panelX + panelW - cornerSize},${adjustedY}`,
    `${panelX + panelW},${adjustedY + cornerSize}`,
    `${panelX + panelW},${adjustedY + panelH - cornerSize}`,
    `${panelX + panelW - cornerSize},${adjustedY + panelH}`,
    `${panelX + cornerSize},${adjustedY + panelH}`,
    `${panelX},${adjustedY + panelH - cornerSize}`,
    `${panelX},${adjustedY + cornerSize}`,
  ].join(" ");

  const cx = panelX + panelW / 2;

  return (
    <g opacity={panelOpacity}>
      <polygon
        points={clipPath}
        fill="#040410"
        stroke={color}
        strokeWidth={1.5}
        style={{ filter: `drop-shadow(0 0 10px ${color}50)` }}
      />
      <polygon points={clipPath} fill={color} opacity={0.03} />

      <line
        x1={panelX + 20}
        y1={adjustedY + 36}
        x2={panelX + panelW - 20}
        y2={adjustedY + 36}
        stroke={color}
        strokeWidth={0.5}
        opacity={0.3}
      />

      <text
        x={cx}
        y={adjustedY + 26}
        textAnchor="middle"
        fill={color}
        fontSize={18}
        fontFamily="'JetBrains Mono', monospace"
        fontWeight="700"
        letterSpacing={2}
        style={{ filter: `drop-shadow(0 0 8px ${color})` }}
      >
        {event.chain}
      </text>

      <g
        transform={`translate(${panelX + 56}, ${adjustedY + 80}) scale(${checkScale})`}
        opacity={detailsOpacity}
      >
        <circle
          r={22}
          fill="none"
          stroke="#00ff88"
          strokeWidth={2}
          style={{ filter: "drop-shadow(0 0 8px #00ff88)" }}
        />
        <text x={0} y={8} textAnchor="middle" fill="#00ff88" fontSize={22} fontWeight="700">
          ✓
        </text>
      </g>

      <g opacity={detailsOpacity}>
        <text
          x={panelX + 92}
          y={adjustedY + 73}
          fill="#00ff88"
          fontSize={15}
          fontFamily="'JetBrains Mono', monospace"
          fontWeight="700"
          letterSpacing={1}
          style={{ filter: "drop-shadow(0 0 6px #00ff88)" }}
        >
          RootAnchored ✓
        </text>

        <text
          x={panelX + 30}
          y={adjustedY + 130}
          fill="#666688"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
          letterSpacing={1}
        >
          BLOCK
        </text>
        <text
          x={panelX + 85}
          y={adjustedY + 130}
          fill="#aaaacc"
          fontSize={12}
          fontFamily="'JetBrains Mono', monospace"
          fontWeight="700"
        >
          #{event.block.toLocaleString()}
        </text>

        <text
          x={panelX + 30}
          y={adjustedY + 158}
          fill="#666688"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
          letterSpacing={1}
        >
          TX
        </text>
        <text
          x={panelX + 56}
          y={adjustedY + 158}
          fill="#7777aa"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          {truncateTx(event.tx)}
        </text>

        <text
          x={panelX + 30}
          y={adjustedY + 186}
          fill="#666688"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
          letterSpacing={1}
        >
          ROOT
        </text>
        <text
          x={panelX + 72}
          y={adjustedY + 186}
          fill="#7777aa"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          {`${event.root.slice(0, 12)}...${event.root.slice(-6)}`}
        </text>
      </g>
    </g>
  );
};

export const Anchor: React.FC<AnchorProps> = ({ events }) => {
  const frame = useCurrentFrame();
  const localFrame = frame - SCENE_START;

  const anchorEvents = events.filter((e): e is AnchorEvent => e.type === "anchor");

  const titleOpacity = interpolate(localFrame, [0, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const rootOpacity = interpolate(localFrame, [15, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const finalMsgOpacity = interpolate(localFrame, [300, 340], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const finalMsgScale = spring({
    frame: Math.max(0, localFrame - 300),
    fps: 30,
    config: { damping: 14, stiffness: 60, mass: 1.2 },
  });

  const scanlineY = ((localFrame * 3.5) % 1080);

  return (
    <AbsoluteFill style={{ background: "#000000" }}>
      <svg
        width={1920}
        height={1080}
        viewBox="0 0 1920 1080"
        style={{ position: "absolute", top: 0, left: 0 }}
      >
        <defs>
          <pattern id="ancgrid" width={45} height={45} patternUnits="userSpaceOnUse">
            <path d="M 45 0 L 0 0 0 45" fill="none" stroke="#0a0a14" strokeWidth={0.5} />
          </pattern>
          <radialGradient id="ancGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#001100" stopOpacity={0.5} />
            <stop offset="100%" stopColor="#000000" stopOpacity={0} />
          </radialGradient>
        </defs>

        <rect width={1920} height={1080} fill="url(#ancgrid)" />
        <rect width={1920} height={1080} fill="url(#ancGlow)" />

        <rect x={0} y={scanlineY} width={1920} height={1.5} fill="#00ff88" opacity={0.03} />

        <g opacity={0.3}>
          <line x1={0} y1={0} x2={80} y2={0} stroke="#00ff88" strokeWidth={1} />
          <line x1={0} y1={0} x2={0} y2={80} stroke="#00ff88" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1840} y2={0} stroke="#00ff88" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1920} y2={80} stroke="#00ff88" strokeWidth={1} />
          <line x1={0} y1={1080} x2={80} y2={1080} stroke="#00ff88" strokeWidth={1} />
          <line x1={0} y1={1080} x2={0} y2={1000} stroke="#00ff88" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1840} y2={1080} stroke="#00ff88" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1920} y2={1000} stroke="#00ff88" strokeWidth={1} />
        </g>

        <g opacity={titleOpacity}>
          <text
            x={960}
            y={92}
            textAnchor="middle"
            fill="#00ff88"
            fontSize={40}
            fontFamily="'JetBrains Mono', monospace"
            fontWeight="700"
            letterSpacing={4}
            style={{ filter: "drop-shadow(0 0 14px #00ff88) drop-shadow(0 0 30px #00ff8860)" }}
          >
            State Root Anchored
          </text>
          <text
            x={960}
            y={126}
            textAnchor="middle"
            fill="#446644"
            fontSize={13}
            fontFamily="'JetBrains Mono', monospace"
            letterSpacing={3}
          >
            On-Chain Finality — ZK Sovereign Rollup
          </text>
          <line x1={360} y1={144} x2={1560} y2={144} stroke="#00ff88" strokeWidth={0.5} opacity={0.25} />
        </g>

        <g opacity={rootOpacity}>
          <text
            x={960}
            y={186}
            textAnchor="middle"
            fill="#446644"
            fontSize={11}
            fontFamily="'JetBrains Mono', monospace"
            letterSpacing={2}
          >
            ROOT HASH
          </text>
          <text
            x={960}
            y={208}
            textAnchor="middle"
            fill="#559955"
            fontSize={12}
            fontFamily="'JetBrains Mono', monospace"
          >
            {ROOT_HASH}
          </text>
        </g>

        {anchorEvents[0] && (
          <AnchorPanel
            event={anchorEvents[0]}
            localFrame={localFrame}
            panelStartFrame={30}
            panelX={100}
            panelY={240}
            color="#ff4444"
          />
        )}
        {anchorEvents[1] && (
          <AnchorPanel
            event={anchorEvents[1]}
            localFrame={localFrame}
            panelStartFrame={90}
            panelX={1100}
            panelY={240}
            color="#4488ff"
          />
        )}

        <DataPulse x={460} y={530} color="#ff4444" frame={localFrame} interval={70} />
        <DataPulse x={1460} y={530} color="#4488ff" frame={localFrame + 25} interval={70} />

        <line
          x1={960}
          y1={240}
          x2={960}
          y2={550}
          stroke="#113311"
          strokeWidth={1}
          strokeDasharray="3 6"
          opacity={interpolate(localFrame, [90, 110], [0, 0.6], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />

        {localFrame > 295 && (
          <g
            opacity={finalMsgOpacity}
            transform={`translate(960, 760) scale(${finalMsgScale})`}
          >
            <rect x={-480} y={-40} width={960} height={88} rx={6} fill="#020208" stroke="#00ff88" strokeWidth={1.5} />
            <rect x={-480} y={-40} width={960} height={88} rx={6} fill="#00ff88" opacity={0.04} />

            <line x1={-480} y1={-40} x2={-450} y2={-40} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={-480} y1={-40} x2={-480} y2={-10} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={480} y1={-40} x2={450} y2={-40} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={480} y1={-40} x2={480} y2={-10} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={-480} y1={48} x2={-450} y2={48} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={-480} y1={48} x2={-480} y2={18} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={480} y1={48} x2={450} y2={48} stroke="#00ff88" strokeWidth={2} opacity={0.8} />
            <line x1={480} y1={48} x2={480} y2={18} stroke="#00ff88" strokeWidth={2} opacity={0.8} />

            <text
              x={0}
              y={-6}
              textAnchor="middle"
              fill="#00ff88"
              fontSize={26}
              fontFamily="'JetBrains Mono', monospace"
              fontWeight="700"
              letterSpacing={2}
              style={{
                filter:
                  "drop-shadow(0 0 12px #00ff88) drop-shadow(0 0 30px #00ff8880) drop-shadow(0 0 60px #00ff8840)",
              }}
            >
              xB77 Sovereign OS
            </text>
            <text
              x={0}
              y={28}
              textAnchor="middle"
              fill="#446644"
              fontSize={14}
              fontFamily="'JetBrains Mono', monospace"
              letterSpacing={3}
            >
              ZK-Proven on Arbitrum
            </text>
          </g>
        )}

        <g
          opacity={interpolate(localFrame, [120, 150], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        >
          {[
            { label: "TRADES", value: "12" },
            { label: "AGENTS", value: "4" },
            { label: "CHAINS", value: "2" },
            { label: "PROOF", value: "UltraPlonk" },
          ].map((stat, i) => {
            const sx = 200 + i * 380;
            return (
              <g key={stat.label}>
                <text
                  x={sx}
                  y={890}
                  textAnchor="middle"
                  fill="#446644"
                  fontSize={10}
                  fontFamily="'JetBrains Mono', monospace"
                  letterSpacing={2}
                >
                  {stat.label}
                </text>
                <text
                  x={sx}
                  y={914}
                  textAnchor="middle"
                  fill="#00ff88"
                  fontSize={20}
                  fontFamily="'JetBrains Mono', monospace"
                  fontWeight="700"
                  style={{ filter: "drop-shadow(0 0 6px #00ff88)" }}
                >
                  {stat.value}
                </text>
              </g>
            );
          })}
        </g>

        <text
          x={1880}
          y={1060}
          textAnchor="end"
          fill="#333333"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          {String(frame).padStart(4, "0")} / 1799
        </text>
      </svg>
    </AbsoluteFill>
  );
};
