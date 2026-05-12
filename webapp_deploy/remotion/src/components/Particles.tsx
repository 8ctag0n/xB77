import React from "react";
import { COLORS } from "../theme";

/**
 * Particle agents — the brand's living motion vocabulary.
 *
 * 12 autonomous agents drift in from outside the bezel, ingress through the 4
 * notch midpoints, converge on the monogram (compression), and dissolve as the
 * hash emits below. Each particle has a fixed phaseOffset so at any time the
 * stream is continuous and the loop is seamless.
 *
 * Per-cycle phases (t = (cycle + phaseOffset) mod 1):
 *   0.00 → 0.55   approach: spawn → notch    (cyan, growing)
 *   0.55 → 0.78   ingress:  notch → center    (cyan → lime, brighter)
 *   0.78 → 1.00   emit:     center → fade-out
 */

export type ParticlesProps = {
  cycle: number; // 0..1
  count?: number;
  idScope?: string;
};

// Bezel notch midpoints in 64-viewBox coords
const NOTCHES: ReadonlyArray<{ x: number; y: number; nx: number; ny: number }> = [
  { x: 32, y: 3,  nx:  0, ny: -1 }, // top:    inward = +y
  { x: 61, y: 32, nx:  1, ny:  0 }, // right:  inward = -x
  { x: 32, y: 61, nx:  0, ny:  1 }, // bottom: inward = -y
  { x: 3,  y: 32, nx: -1, ny:  0 }, // left:   inward = +x
];

const CENTER = { x: 32, y: 36 };

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const easeInOut = (t: number) => t * t * (3 - 2 * t);

type Particle = {
  id: number;
  phaseOffset: number;
  notchIdx: number;
  lateralOffset: number; // perpendicular offset along the entry path
  spawnDistance: number; // how far outside the bezel it starts
};

function makeParticles(count: number): Particle[] {
  const result: Particle[] = [];
  for (let i = 0; i < count; i++) {
    result.push({
      id: i,
      phaseOffset: i / count,
      notchIdx: i % 4,
      // deterministic but non-trivial lateral spread
      lateralOffset: ((i * 7) % 11) / 11 * 5 - 2.5,
      spawnDistance: 6 + ((i * 13) % 7),
    });
  }
  return result;
}

type RenderedParticle = {
  cx: number;
  cy: number;
  r: number;
  fill: string;
  opacity: number;
};

function computeParticle(p: Particle, cycle: number): RenderedParticle {
  const t = (cycle + p.phaseOffset) % 1;
  const notch = NOTCHES[p.notchIdx];

  // Tangent vector for lateral offset (perpendicular to the notch normal)
  const tx = -notch.ny;
  const ty = notch.nx;

  const spawnX = notch.x + notch.nx * p.spawnDistance + tx * p.lateralOffset;
  const spawnY = notch.y + notch.ny * p.spawnDistance + ty * p.lateralOffset;
  const notchX = notch.x + tx * (p.lateralOffset * 0.2); // converge slightly on approach
  const notchY = notch.y + ty * (p.lateralOffset * 0.2);

  let cx: number, cy: number, r: number, opacity: number, fillMix: number;

  if (t < 0.55) {
    // Approach phase: drift toward notch
    const a = easeInOut(t / 0.55);
    cx = lerp(spawnX, notchX, a);
    cy = lerp(spawnY, notchY, a);
    r = lerp(0.3, 0.85, a);
    opacity = lerp(0.0, 0.85, Math.min(1, a * 1.6));
    fillMix = 0;
  } else if (t < 0.78) {
    // Ingress phase: notch → center, intensify
    const a = easeInOut((t - 0.55) / 0.23);
    cx = lerp(notchX, CENTER.x, a);
    cy = lerp(notchY, CENTER.y, a);
    r = lerp(0.85, 1.25, a);
    opacity = lerp(0.85, 1.0, a);
    fillMix = a;
  } else {
    // Emit phase: collapse to a point and fade
    const a = easeInOut((t - 0.78) / 0.22);
    cx = CENTER.x;
    cy = lerp(CENTER.y, CENTER.y + 2, a);
    r = lerp(1.25, 0.0, a);
    opacity = lerp(1.0, 0.0, a);
    fillMix = 1;
  }

  // Color: cyan during approach, blends to lime during ingress/emit
  const fill = fillMix > 0.5 ? COLORS.lime : COLORS.cyan;

  return { cx, cy, r, fill, opacity };
}

// Memoized particle config — count rarely changes
const PARTICLES_CACHE = new Map<number, Particle[]>();
function getParticles(count: number): Particle[] {
  let list = PARTICLES_CACHE.get(count);
  if (!list) {
    list = makeParticles(count);
    PARTICLES_CACHE.set(count, list);
  }
  return list;
}

export const Particles: React.FC<ParticlesProps> = ({
  cycle,
  count = 12,
  idScope = "xb-particles",
}) => {
  const particles = getParticles(count);

  return (
    <g aria-hidden="true">
      {particles.map((p) => {
        const r = computeParticle(p, cycle);
        return (
          <circle
            key={`${idScope}-${p.id}`}
            cx={r.cx}
            cy={r.cy}
            r={r.r}
            fill={r.fill}
            opacity={r.opacity}
          />
        );
      })}
    </g>
  );
};

/**
 * Compression intensity — how many particles are currently near the center.
 * Compositions read this to brighten the monogram during the convergence beat.
 * Returns 0..1.
 */
export function compressionIntensity(cycle: number, count = 12): number {
  const particles = getParticles(count);
  let near = 0;
  for (const p of particles) {
    const t = (cycle + p.phaseOffset) % 1;
    if (t >= 0.62 && t <= 0.80) near++;
  }
  return Math.min(1, near / 3);
}
