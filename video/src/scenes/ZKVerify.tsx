import React from "react";
import { useCurrentFrame, AbsoluteFill, interpolate, spring } from "remotion";
import type { Event, ZKVerifyEvent } from "../data/parseEvents";

interface ZKVerifyProps {
  events: Event[];
}

const SCENE_START = 600;

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 10)}...${addr.slice(-6)}`;
}

function truncateTx(tx: string): string {
  return `${tx.slice(0, 14)}...${tx.slice(-8)}`;
}

interface VerifyPanelProps {
  event: ZKVerifyEvent;
  localFrame: number;
  panelStartFrame: number;
  panelX: number;
}

const VerifyPanel: React.FC<VerifyPanelProps> = ({ event, localFrame, panelStartFrame, panelX }) => {
  const pf = Math.max(0, localFrame - panelStartFrame);

  const panelOpacity = interpolate(pf, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const panelY = interpolate(pf, [0, 30], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Progress bar fills over 150 frames
  const barProgress = interpolate(pf, [20, 150], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Checkmark appears after bar is full
  const checkScale = spring({
    frame: Math.max(0, pf - 150),
    fps: 30,
    config: { damping: 10, stiffness: 100, mass: 0.8 },
  });

  const txOpacity = interpolate(pf, [160, 185], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const color = event.chain.toLowerCase().includes("robinhood") ? "#ff4444" : "#4488ff";
  const panelW = 700;
  const panelH = 340;
  const panelYBase = 330;
  const cornerSize = 12;

  const clipPath = [
    `${panelX + cornerSize},${panelYBase + panelY}`,
    `${panelX + panelW - cornerSize},${panelYBase + panelY}`,
    `${panelX + panelW},${panelYBase + cornerSize + panelY}`,
    `${panelX + panelW},${panelYBase + panelH - cornerSize + panelY}`,
    `${panelX + panelW - cornerSize},${panelYBase + panelH + panelY}`,
    `${panelX + cornerSize},${panelYBase + panelH + panelY}`,
    `${panelX},${panelYBase + panelH - cornerSize + panelY}`,
    `${panelX},${panelYBase + cornerSize + panelY}`,
  ].join(" ");

  const barMaxW = panelW - 60;
  const barFilledW = barMaxW * barProgress;

  const cx = panelX + panelW / 2;
  const cy = panelYBase + panelH / 2 + panelY;

  return (
    <g opacity={panelOpacity}>
      {/* Panel background */}
      <polygon
        points={clipPath}
        fill="#04040f"
        stroke={color}
        strokeWidth={1.5}
        style={{ filter: `drop-shadow(0 0 10px ${color}60)` }}
      />
      <polygon points={clipPath} fill={color} opacity={0.03} />

      {/* Chain name */}
      <text
        x={cx}
        y={panelYBase + 44 + panelY}
        textAnchor="middle"
        fill={color}
        fontSize={20}
        fontFamily="'JetBrains Mono', monospace"
        fontWeight="700"
        letterSpacing={2}
        style={{ filter: `drop-shadow(0 0 8px ${color})` }}
      >
        {event.chain}
      </text>

      {/* Label: contract */}
      <text
        x={panelX + 30}
        y={panelYBase + 82 + panelY}
        fill="#666688"
        fontSize={10}
        fontFamily="'JetBrains Mono', monospace"
        letterSpacing={1}
      >
        CONTRACT
      </text>
      <text
        x={panelX + 30}
        y={panelYBase + 100 + panelY}
        fill="#aaaacc"
        fontSize={11}
        fontFamily="'JetBrains Mono', monospace"
      >
        {truncateAddr(event.contract)}
      </text>

      {/* Progress bar background */}
      <rect
        x={panelX + 30}
        y={panelYBase + 120 + panelY}
        width={barMaxW}
        height={12}
        rx={3}
        fill="#111133"
        stroke={color}
        strokeWidth={0.8}
        opacity={0.8}
      />

      {/* Progress bar fill */}
      <rect
        x={panelX + 30}
        y={panelYBase + 120 + panelY}
        width={barFilledW}
        height={12}
        rx={3}
        fill={color}
        opacity={0.8}
        style={{ filter: `drop-shadow(0 0 4px ${color})` }}
      />

      {/* Progress label */}
      <text
        x={panelX + 30 + barMaxW / 2}
        y={panelYBase + 130 + panelY}
        textAnchor="middle"
        fill="#ffffff"
        fontSize={8}
        fontFamily="'JetBrains Mono', monospace"
        fontWeight="700"
      >
        {Math.round(barProgress * 100)}%
      </text>

      {/* Verification steps */}
      {["Witness generation", "Proof computation", "Verification"].map((step, si) => {
        const stepProgress = interpolate(barProgress, [si * 0.33, (si + 1) * 0.33], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        const stepDone = stepProgress >= 1;
        return (
          <g key={step}>
            <text
              x={panelX + 40}
              y={panelYBase + 158 + si * 24 + panelY}
              fill={stepDone ? color : "#444466"}
              fontSize={11}
              fontFamily="'JetBrains Mono', monospace"
            >
              {stepDone ? "✓" : "○"} {step}
            </text>
          </g>
        );
      })}

      {/* Checkmark */}
      {pf > 150 && (
        <g transform={`translate(${cx}, ${panelYBase + 255 + panelY}) scale(${checkScale})`}>
          <circle r={28} fill="none" stroke="#00ff88" strokeWidth={2.5} opacity={0.9}
            style={{ filter: "drop-shadow(0 0 10px #00ff88)" }} />
          <text
            x={0}
            y={10}
            textAnchor="middle"
            fill="#00ff88"
            fontSize={28}
            fontWeight="700"
          >
            ✓
          </text>
        </g>
      )}

      {/* TX hash */}
      <g opacity={txOpacity}>
        <text
          x={panelX + 30}
          y={panelYBase + 302 + panelY}
          fill="#555577"
          fontSize={9}
          fontFamily="'JetBrains Mono', monospace"
        >
          TX
        </text>
        <text
          x={panelX + 52}
          y={panelYBase + 302 + panelY}
          fill="#7777aa"
          fontSize={9}
          fontFamily="'JetBrains Mono', monospace"
        >
          {truncateTx(event.tx)}
        </text>
        <text
          x={panelX + 30}
          y={panelYBase + 320 + panelY}
          fill="#555577"
          fontSize={9}
          fontFamily="'JetBrains Mono', monospace"
        >
          RESULT
        </text>
        <text
          x={panelX + 82}
          y={panelYBase + 320 + panelY}
          fill="#00ff88"
          fontSize={9}
          fontFamily="'JetBrains Mono', monospace"
          fontWeight="700"
        >
          0x0000...0001
        </text>
      </g>
    </g>
  );
};

export const ZKVerify: React.FC<ZKVerifyProps> = ({ events }) => {
  const frame = useCurrentFrame();
  const localFrame = frame - SCENE_START;

  const zkEvents = events.filter((e): e is ZKVerifyEvent => e.type === "zk_verify");

  const titleOpacity = interpolate(localFrame, [0, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const scanlineY = ((localFrame * 4) % 1080);

  return (
    <AbsoluteFill style={{ background: "#000000" }}>
      <svg
        width={1920}
        height={1080}
        viewBox="0 0 1920 1080"
        style={{ position: "absolute", top: 0, left: 0 }}
      >
        <defs>
          <pattern id="zkgrid" width={40} height={40} patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#0a0a1a" strokeWidth={0.5} />
          </pattern>
          <radialGradient id="zkGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#001122" stopOpacity={0.6} />
            <stop offset="100%" stopColor="#000000" stopOpacity={0} />
          </radialGradient>
        </defs>

        <rect width={1920} height={1080} fill="url(#zkgrid)" />
        <rect width={1920} height={1080} fill="url(#zkGlow)" />

        {/* Scanline */}
        <rect x={0} y={scanlineY} width={1920} height={1.5} fill="#4488ff" opacity={0.04} />

        {/* Corner decorations */}
        <g opacity={0.35}>
          <line x1={0} y1={0} x2={80} y2={0} stroke="#4488ff" strokeWidth={1} />
          <line x1={0} y1={0} x2={0} y2={80} stroke="#4488ff" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1840} y2={0} stroke="#4488ff" strokeWidth={1} />
          <line x1={1920} y1={0} x2={1920} y2={80} stroke="#4488ff" strokeWidth={1} />
          <line x1={0} y1={1080} x2={80} y2={1080} stroke="#4488ff" strokeWidth={1} />
          <line x1={0} y1={1080} x2={0} y2={1000} stroke="#4488ff" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1840} y2={1080} stroke="#4488ff" strokeWidth={1} />
          <line x1={1920} y1={1080} x2={1920} y2={1000} stroke="#4488ff" strokeWidth={1} />
        </g>

        {/* Title */}
        <g opacity={titleOpacity}>
          <text
            x={960}
            y={100}
            textAnchor="middle"
            fill="#4488ff"
            fontSize={40}
            fontFamily="'JetBrains Mono', monospace"
            fontWeight="700"
            letterSpacing={4}
            style={{ filter: "drop-shadow(0 0 12px #4488ff) drop-shadow(0 0 30px #4488ff60)" }}
          >
            ZK Proof Verification
          </text>
          <text
            x={960}
            y={134}
            textAnchor="middle"
            fill="#555577"
            fontSize={14}
            fontFamily="'JetBrains Mono', monospace"
            letterSpacing={3}
          >
            UltraPlonk — Batch #{`0x190d...f3a4`}
          </text>

          {/* Separator line */}
          <line x1={360} y1={152} x2={1560} y2={152} stroke="#4488ff" strokeWidth={0.5} opacity={0.3} />
        </g>

        {/* Two panels side by side */}
        {zkEvents[0] && (
          <VerifyPanel
            event={zkEvents[0]}
            localFrame={localFrame}
            panelStartFrame={10}
            panelX={110}
          />
        )}
        {zkEvents[1] && (
          <VerifyPanel
            event={zkEvents[1]}
            localFrame={localFrame}
            panelStartFrame={40}
            panelX={1110}
          />
        )}

        {/* Center divider */}
        <line
          x1={960}
          y1={300}
          x2={960}
          y2={730}
          stroke="#222244"
          strokeWidth={1}
          strokeDasharray="4 8"
          opacity={0.5}
        />

        {/* Frame counter */}
        <text
          x={1880}
          y={1060}
          textAnchor="end"
          fill="#333333"
          fontSize={10}
          fontFamily="'JetBrains Mono', monospace"
        >
          {String(frame).padStart(4, "0")} / 0999
        </text>
      </svg>
    </AbsoluteFill>
  );
};
