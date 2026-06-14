import React from "react";
import { useCurrentFrame, spring, interpolate } from "remotion";

interface AgentNodeProps {
  x: number;
  y: number;
  color: string;
  name: string;
  pulse: number; // 0-1
  startFrame: number;
  missionText?: string;
}

export const AgentNode: React.FC<AgentNodeProps> = ({
  x,
  y,
  color,
  name,
  pulse,
  startFrame,
  missionText,
}) => {
  const frame = useCurrentFrame();

  const localFrame = Math.max(0, frame - startFrame);

  const entryScale = spring({
    frame: localFrame,
    fps: 30,
    config: {
      damping: 12,
      stiffness: 80,
      mass: 1,
    },
  });

  const pulseScale = 1 + pulse * 0.18;
  const finalScale = entryScale * (1 + (pulseScale - 1) * Math.min(1, localFrame / 30));

  const glowOpacity = interpolate(localFrame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const hexSize = 48;

  // Hexagon points
  const hexPoints = Array.from({ length: 6 }, (_, i) => {
    const angle = (Math.PI / 3) * i - Math.PI / 6;
    return `${hexSize * Math.cos(angle)},${hexSize * Math.sin(angle)}`;
  }).join(" ");

  const ringPulse = (frame % 60) / 60;
  const ringRadius = 48 + ringPulse * 30;
  const ringOpacity = (1 - ringPulse) * 0.6 * glowOpacity;

  const missionOpacity = missionText
    ? interpolate(localFrame, [0, 20], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  return (
    <g transform={`translate(${x}, ${y})`}>
      {/* Outer pulsing ring */}
      <circle
        cx={0}
        cy={0}
        r={ringRadius}
        fill="none"
        stroke={color}
        strokeWidth={1.5}
        opacity={ringOpacity}
      />

      {/* Glow halo */}
      <circle
        cx={0}
        cy={0}
        r={62}
        fill={color}
        opacity={0.06 * glowOpacity * (1 + pulse * 0.5)}
      />

      {/* Main hexagon group with entry scale */}
      <g transform={`scale(${finalScale})`}>
        {/* Hexagon background */}
        <polygon
          points={hexPoints}
          fill="#0a0a0a"
          stroke={color}
          strokeWidth={2.5}
          style={{
            filter: `drop-shadow(0 0 8px ${color}) drop-shadow(0 0 20px ${color}80)`,
          }}
          opacity={glowOpacity}
        />

        {/* Inner glow fill */}
        <polygon
          points={hexPoints}
          fill={color}
          opacity={0.08 * glowOpacity}
        />

        {/* Center dot */}
        <circle
          cx={0}
          cy={0}
          r={6}
          fill={color}
          opacity={glowOpacity}
          style={{ filter: `drop-shadow(0 0 4px ${color})` }}
        />

        {/* Corner accent lines */}
        <line x1={-20} y1={0} x2={20} y2={0} stroke={color} strokeWidth={0.5} opacity={0.4 * glowOpacity} />
        <line x1={0} y1={-20} x2={0} y2={20} stroke={color} strokeWidth={0.5} opacity={0.4 * glowOpacity} />
      </g>

      {/* Agent name label */}
      <text
        x={0}
        y={78}
        textAnchor="middle"
        fill={color}
        fontSize={13}
        fontFamily="'JetBrains Mono', 'Fira Code', monospace"
        fontWeight="700"
        letterSpacing={2}
        opacity={glowOpacity}
        style={{ filter: `drop-shadow(0 0 6px ${color})` }}
      >
        {name}
      </text>

      {/* Mission text */}
      {missionText && (
        <text
          x={0}
          y={96}
          textAnchor="middle"
          fill="#ffffff"
          fontSize={9}
          fontFamily="'JetBrains Mono', 'Fira Code', monospace"
          opacity={missionOpacity * 0.8}
          letterSpacing={0.5}
        >
          {missionText.length > 32 ? missionText.slice(0, 32) + "…" : missionText}
        </text>
      )}
    </g>
  );
};
