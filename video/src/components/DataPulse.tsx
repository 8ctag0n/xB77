import React from "react";
import { interpolate } from "remotion";

interface DataPulseProps {
  x: number;
  y: number;
  color: string;
  frame: number;
  interval: number;
}

export const DataPulse: React.FC<DataPulseProps> = ({
  x,
  y,
  color,
  frame,
  interval,
}) => {
  // Generate 3 staggered rings
  const rings = [0, Math.floor(interval / 3), Math.floor((interval * 2) / 3)];

  return (
    <g>
      {rings.map((offset, i) => {
        const localFrame = ((frame + offset) % interval) / interval;

        const radius = interpolate(localFrame, [0, 1], [10, 80], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

        const opacity = interpolate(localFrame, [0, 0.3, 1], [0.8, 0.5, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

        const strokeWidth = interpolate(localFrame, [0, 1], [2.5, 0.5], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

        return (
          <circle
            key={i}
            cx={x}
            cy={y}
            r={radius}
            fill="none"
            stroke={color}
            strokeWidth={strokeWidth}
            opacity={opacity}
          />
        );
      })}

      {/* Center dot */}
      <circle
        cx={x}
        cy={y}
        r={4}
        fill={color}
        opacity={0.9}
        style={{ filter: `drop-shadow(0 0 4px ${color})` }}
      />
    </g>
  );
};
