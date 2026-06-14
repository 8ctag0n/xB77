import React from "react";
import { interpolate } from "remotion";

interface TxArrowProps {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  color: string;
  progress: number; // 0-1
  token: string;
  amount: number;
}

export const TxArrow: React.FC<TxArrowProps> = ({
  x1,
  y1,
  x2,
  y2,
  color,
  progress,
  token,
  amount,
}) => {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const length = Math.sqrt(dx * dx + dy * dy);

  // Midpoint for label
  const mx = x1 + dx * 0.5;
  const my = y1 + dy * 0.5;

  // Arrowhead angle
  const angle = Math.atan2(dy, dx) * (180 / Math.PI);

  // Dash animation: total line length drawn = progress * length
  const drawnLength = progress * length;
  const dashArray = `${drawnLength} ${length}`;
  const dashOffset = 0;

  const lineOpacity = interpolate(progress, [0, 0.05], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const labelOpacity = interpolate(progress, [0.5, 0.65], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const arrowOpacity = interpolate(progress, [0.85, 1.0], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Particle position along the line
  const px = x1 + dx * Math.min(progress, 0.97);
  const py = y1 + dy * Math.min(progress, 0.97);

  const markerId = `arrow-${color.replace("#", "")}-${Math.round(x1)}-${Math.round(y1)}`;

  return (
    <g>
      <defs>
        <marker
          id={markerId}
          markerWidth={8}
          markerHeight={8}
          refX={6}
          refY={3}
          orient="auto"
        >
          <path
            d="M0,0 L0,6 L8,3 z"
            fill={color}
            opacity={arrowOpacity}
          />
        </marker>
      </defs>

      {/* Main line with dash animation */}
      <line
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        stroke={color}
        strokeWidth={1.5}
        strokeDasharray={dashArray}
        strokeDashoffset={dashOffset}
        opacity={lineOpacity * 0.7}
        style={{ filter: `drop-shadow(0 0 3px ${color})` }}
        markerEnd={`url(#${markerId})`}
      />

      {/* Glow line (wider, more transparent) */}
      <line
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        stroke={color}
        strokeWidth={4}
        strokeDasharray={dashArray}
        strokeDashoffset={dashOffset}
        opacity={lineOpacity * 0.15}
      />

      {/* Traveling particle */}
      {progress > 0.02 && progress < 0.98 && (
        <circle
          cx={px}
          cy={py}
          r={4}
          fill={color}
          opacity={0.9}
          style={{ filter: `drop-shadow(0 0 5px ${color})` }}
        />
      )}

      {/* Amount label at midpoint */}
      {progress > 0.5 && (
        <g opacity={labelOpacity}>
          <rect
            x={mx - 42}
            y={my - 14}
            width={84}
            height={20}
            fill="#000000"
            rx={3}
            opacity={0.85}
          />
          <rect
            x={mx - 42}
            y={my - 14}
            width={84}
            height={20}
            fill="none"
            stroke={color}
            strokeWidth={0.8}
            rx={3}
            opacity={0.6}
          />
          <text
            x={mx}
            y={my - 1}
            textAnchor="middle"
            fill={color}
            fontSize={9}
            fontFamily="'JetBrains Mono', monospace"
            fontWeight="700"
          >
            {amount.toLocaleString()} {token}
          </text>
        </g>
      )}
    </g>
  );
};
