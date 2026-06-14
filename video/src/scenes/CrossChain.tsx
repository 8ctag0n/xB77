import React from "react";
import { useCurrentFrame, AbsoluteFill, interpolate } from "remotion";
import type { Event, XChainBridgeEvent } from "../data/parseEvents";
import { ChainBadge } from "../components/ChainBadge";
import { DataPulse } from "../components/DataPulse";

interface CrossChainProps {
  events: Event[];
}

const SCENE_START = 1000;

const ROOT_HASH = "0x190d33b12f986f961f9c5b4e7f98cae2c7b66a0e4f1c3d2e5a8b9c0d1e2f3a4";

export const CrossChain: React.FC<CrossChainProps> = ({ events }) => {
  const frame = useCurrentFrame();
  const localFrame = frame - SCENE_START;

  const bridgeEvents = events.filter((e): e is XChainBridgeEvent => e.type === "xchain_bridge");

  const titleOpacity = interpolate(localFrame, [0, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const badgeLeftOpacity = interpolate(localFrame, [5, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const badgeRightOpacity = interpolate(localFrame, [20, 45], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const lineOpacity = interpolate(localFrame, [40, 60], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Particle travels from left badge (x≈480) to right badge (x≈1320)
  const particleX = interpolate(localFrame, [30, 130], [480, 1320], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const particleVisible = localFrame >= 30 && localFrame <= 130;

  const labelOpacity = interpolate(localFrame, [50, 75], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Animated dash offset for the connecting line
  const dashOffset = -(localFrame * 3) % 40;

  const scanlineY = ((localFrame * 5) % 1080);

  // Short root display
  const shortRoot = `${ROOT_HASH.slice(0, 10)}...${ROOT_HASH.slice(-6)}`;

  return (
    <AbsoluteFill style={{ background: "#000000" }}>
      <svg
        width={1920}
        height={1080}
        viewBox="0 0 1920 1080"
        style={{ position: "absolute", top: 0, left: 0 }}
      >
        <defs>
          <pattern id="ccgrid" width={50} height={50} patternUnits="userSpaceOnUse">
            <path d="M 50 0 L 0 0 0 50" fill="none" stroke="#0a0a14" strokeWidth={0.5} />
          </pattern>
          <radialGradient id="ccGlow" cx="30%" cy="50%" r="40%">
            <stop offset="0%" stopColor="#220000" stopOpacity={0.4} />
            <stop offset="100%" stopColor="#000000" stopOpacity={0} />
          </radialGradient>
          <radialGradient id="ccGlow2" cx="70%" cy="50%" r="40%">
            <stop offset="0%" stopColor="#001122" stopOpacity={0.4} />
            <stop offset="100%" stopColor="#000000" stopOpacity={0} />
          </radialGradient>
          <filter id="particleGlow">
            <feGaussianBlur stdDeviation={4} result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        <rect width={1920} height={1080} fill="url(#ccgrid)" />
        <rect width={1920} height={1080} fill="url(#ccGlow)" />
        <rect width={1920} height={1080} fill="url(#ccGlow2)" />

        {/* Scanline */}
        <rect x={0} y={scanlineY} width={1920} height={1.5} fill="#ff4444" opacity={0.03} />

        {/* Corner decorations */}
        <g opacity={0.3}>
          {[0, 1920].flatMap((bx) =>
            [0, 1080].map((by) => {
              const sx = bx === 0 ? 1 : -1;
              const sy = by === 0 ? 1 : -1;
              const c = bx === 0 ? "#ff4444" : "#4488ff";
              return (
                <g key={`${bx}-${by}`}>
                  <line x1={bx} y1={by} x2={bx + sx * 70} y2={by} stroke={c} strokeWidth={1} />
                  <line x1={bx} y1={by} x2={bx} y2={by + sy * 70} stroke={c} strokeWidth={1} />
                </g>
              );
            })
          )}
        </g>

        {/* Title */}
        <g opacity={titleOpacity}>
          <text
            x={960}
            y={100}
            textAnchor="middle"
            fill="#ffffff"
            fontSize={40}
            fontFamily="'JetBrains Mono', monospace"
            fontWeight="700"
            letterSpacing={4}
            style={{ filter: "drop-shadow(0 0 10px #ffffff60)" }}
          >
            Cross-Chain Bridge
          </text>
          <text
            x={960}
            y={134}
            textAnchor="middle"
            fill="#555577"
            fontSize={14}
            fontFamily="'JetBrains Mono', monospace"
            letterSpacing={2}
          >
            State Root Transfer — Trustless Bridge
          </text>
          <line x1={360} y1={152} x2={1560} y2={152} stroke="#555577" strokeWidth={0.5} opacity={0.3} />
        </g>

        {/* Left chain badge */}
        <g opacity={badgeLeftOpacity}>
          <ChainBadge
            name="Robinhood Chain"
            color="#ff4444"
            x={100}
            y={400}
            width={380}
            height={160}
          />
        </g>

        {/* Right chain badge */}
        <g opacity={badgeRightOpacity}>
          <ChainBadge
            name="Arbitrum Sepolia"
            color="#4488ff"
            x={1440}
            y={400}
            width={380}
            height={160}
          />
        </g>

        {/* Connecting line with animated dashes */}
        <g opacity={lineOpacity}>
          <line
            x1={480}
            y1={480}
            x2={1440}
            y2={480}
            stroke="#555577"
            strokeWidth={1}
            strokeDasharray="12 8"
            strokeDashoffset={dashOffset}
            opacity={0.4}
          />
          {/* Glow line */}
          <line
            x1={480}
            y1={480}
            x2={1440}
            y2={480}
            stroke="#ffffff"
            strokeWidth={4}
            opacity={0.03}
          />
        </g>

        {/* Traveling particle */}
        {particleVisible && (
          <g filter="url(#particleGlow)">
            <circle
              cx={particleX}
              cy={480}
              r={10}
              fill="#ffffff"
              opacity={0.95}
            />
            <circle
              cx={particleX}
              cy={480}
              r={20}
              fill="#ffffff"
              opacity={0.15}
            />
            {/* Root hash label traveling with particle */}
            <g opacity={labelOpacity}>
              <rect
                x={particleX - 130}
                y={453}
                width={260}
                height={18}
                rx={3}
                fill="#000000"
                opacity={0.9}
              />
              <text
                x={particleX}
                y={465}
                textAnchor="middle"
                fill="#00ffff"
                fontSize={9}
                fontFamily="'JetBrains Mono', monospace"
              >
                {shortRoot}
              </text>
            </g>
          </g>
        )}

        {/* DataPulse on both sides */}
        <DataPulse x={290} y={480} color="#ff4444" frame={localFrame} interval={60} />
        <DataPulse x={1630} y={480} color="#4488ff" frame={localFrame + 20} interval={60} />

        {/* Bridge details */}
        <g opacity={labelOpacity}>
          <text
            x={960}
            y={600}
            textAnchor="middle"
            fill="#555577"
            fontSize={11}
            fontFamily="'JetBrains Mono', monospace"
            letterSpacing={1}
          >
            STATE ROOT
          </text>
          <text
            x={960}
            y={622}
            textAnchor="middle"
            fill="#aaaacc"
            fontSize={11}
            fontFamily="'JetBrains Mono', monospace"
          >
            {shortRoot}
          </text>

          <text
            x={960}
            y={660}
            textAnchor="middle"
            fill="#555577"
            fontSize={10}
            fontFamily="'JetBrains Mono', monospace"
          >
            12 TRADES · 4 AGENTS · ULTRAPLONK VERIFIED
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
          {String(frame).padStart(4, "0")} / 1199
        </text>
      </svg>
    </AbsoluteFill>
  );
};
