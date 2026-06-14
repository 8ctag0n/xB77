import React from "react";

interface ChainBadgeProps {
  name: string;
  color: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export const ChainBadge: React.FC<ChainBadgeProps> = ({
  name,
  color,
  x,
  y,
  width,
  height,
}) => {
  const cornerSize = 10;

  // Clipped corner polygon path (top-left and bottom-right corners cut)
  const clipPath = [
    `${x + cornerSize},${y}`,
    `${x + width - cornerSize},${y}`,
    `${x + width},${y + cornerSize}`,
    `${x + width},${y + height - cornerSize}`,
    `${x + width - cornerSize},${y + height}`,
    `${x + cornerSize},${y + height}`,
    `${x},${y + height - cornerSize}`,
    `${x},${y + cornerSize}`,
  ].join(" ");

  const cx = x + width / 2;
  const cy = y + height / 2;

  return (
    <g>
      {/* Background polygon with clipped corners */}
      <polygon
        points={clipPath}
        fill="#060610"
        stroke={color}
        strokeWidth={1.5}
        style={{ filter: `drop-shadow(0 0 8px ${color}80) drop-shadow(0 0 20px ${color}40)` }}
      />

      {/* Inner subtle fill glow */}
      <polygon
        points={clipPath}
        fill={color}
        opacity={0.04}
      />

      {/* Top-left accent corner */}
      <line x1={x} y1={y + cornerSize + 8} x2={x} y2={y + cornerSize + 18} stroke={color} strokeWidth={2} opacity={0.8} />
      <line x1={x + cornerSize} y1={y} x2={x + cornerSize + 10} y2={y} stroke={color} strokeWidth={2} opacity={0.8} />

      {/* Bottom-right accent corner */}
      <line x1={x + width} y1={y + height - cornerSize - 8} x2={x + width} y2={y + height - cornerSize - 18} stroke={color} strokeWidth={2} opacity={0.8} />
      <line x1={x + width - cornerSize} y1={y + height} x2={x + width - cornerSize - 10} y2={y + height} stroke={color} strokeWidth={2} opacity={0.8} />

      {/* Horizontal scan line */}
      <line
        x1={x + 2}
        y1={cy - 8}
        x2={x + width - 2}
        y2={cy - 8}
        stroke={color}
        strokeWidth={0.5}
        opacity={0.25}
      />

      {/* Chain icon: small circle */}
      <circle cx={cx} cy={cy - 22} r={8} fill="none" stroke={color} strokeWidth={1.5} opacity={0.8} />
      <circle cx={cx} cy={cy - 22} r={3} fill={color} opacity={0.9} />

      {/* Chain name */}
      <text
        x={cx}
        y={cy + 2}
        textAnchor="middle"
        fill={color}
        fontSize={14}
        fontFamily="'JetBrains Mono', 'Fira Code', monospace"
        fontWeight="700"
        letterSpacing={1.5}
        style={{ filter: `drop-shadow(0 0 6px ${color})` }}
      >
        {name}
      </text>

      {/* Subtitle */}
      <text
        x={cx}
        y={cy + 20}
        textAnchor="middle"
        fill={color}
        fontSize={9}
        fontFamily="'JetBrains Mono', 'Fira Code', monospace"
        opacity={0.6}
        letterSpacing={2}
      >
        CHAIN
      </text>
    </g>
  );
};
