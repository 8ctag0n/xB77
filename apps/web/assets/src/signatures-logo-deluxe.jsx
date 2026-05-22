/* xB77 Signature Component — Logo Deluxe (the Seal, alive)
 *
 * Browser mirror of webapp_deploy/remotion/src/components/Seal.tsx +
 * Particles.tsx. Same staged entrance (bezel traces → monogram stamps → ticks
 * fan → ZK pops) and same agent cycle (12 particles flow in through bezel
 * notches → converge on monogram → emit). The agent cycle loops every 6s via
 * a 30 Hz requestAnimationFrame driver — kicks in after the entrance.
 *
 * Public API (preserved from prior version):
 *   <LogoDeluxe size={N} active={bool} />
 *
 * Consumed by:
 *   - assets/js/variant-a-obsidian.js  (nav, size=40)
 *   - assets/js/shared-architecture-footer.js  (footer, size=36)
 *
 * Exports: window.LogoDeluxe
 */

(function () {
  const { motion } = window.Motion || {
    motion: { div: 'div', svg: 'svg', g: 'g', rect: 'rect', text: 'text', line: 'line', path: 'path', circle: 'circle' },
  };

  const COLORS = {
    bg:       '#08080a',
    lime:     '#c8ff2e',
    midGreen: '#7fe6a8',
    cyan:     '#00f0ff',
  };

  // ===== Particle system (1:1 port of remotion/src/components/Particles.tsx) =====

  const PARTICLE_COUNT = 12;
  const LOOP_MS = 6000;
  const NOTCHES = [
    { x: 32, y: 3,  nx:  0, ny: -1 }, // top
    { x: 61, y: 32, nx:  1, ny:  0 }, // right
    { x: 32, y: 61, nx:  0, ny:  1 }, // bottom
    { x: 3,  y: 32, nx: -1, ny:  0 }, // left
  ];
  const CENTER = { x: 32, y: 36 };
  const lerp = (a, b, t) => a + (b - a) * t;
  const easeInOut = (t) => t * t * (3 - 2 * t);

  const PARTICLES = Array.from({ length: PARTICLE_COUNT }, (_, i) => ({
    phaseOffset: i / PARTICLE_COUNT,
    notchIdx: i % 4,
    lateralOffset: ((i * 7) % 11) / 11 * 5 - 2.5,
    spawnDistance: 6 + ((i * 13) % 7),
  }));

  function computeParticle(p, cycle) {
    const t = (cycle + p.phaseOffset) % 1;
    const n = NOTCHES[p.notchIdx];
    const tx = -n.ny, ty = n.nx;
    const sx = n.x + n.nx * p.spawnDistance + tx * p.lateralOffset;
    const sy = n.y + n.ny * p.spawnDistance + ty * p.lateralOffset;
    const nx = n.x + tx * (p.lateralOffset * 0.2);
    const ny = n.y + ty * (p.lateralOffset * 0.2);
    if (t < 0.55) {
      const a = easeInOut(t / 0.55);
      return {
        cx: lerp(sx, nx, a), cy: lerp(sy, ny, a),
        r: lerp(0.3, 0.85, a),
        opacity: lerp(0, 0.85, Math.min(1, a * 1.6)),
        fill: COLORS.cyan,
      };
    }
    if (t < 0.78) {
      const a = easeInOut((t - 0.55) / 0.23);
      return {
        cx: lerp(nx, CENTER.x, a), cy: lerp(ny, CENTER.y, a),
        r: lerp(0.85, 1.25, a),
        opacity: lerp(0.85, 1.0, a),
        fill: a > 0.5 ? COLORS.lime : COLORS.cyan,
      };
    }
    const a = easeInOut((t - 0.78) / 0.22);
    return {
      cx: CENTER.x, cy: lerp(CENTER.y, CENTER.y + 2, a),
      r: lerp(1.25, 0, a),
      opacity: lerp(1.0, 0, a),
      fill: COLORS.lime,
    };
  }

  function compressionIntensity(cycle) {
    let near = 0;
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const t = (cycle + i / PARTICLE_COUNT) % 1;
      if (t >= 0.62 && t <= 0.80) near++;
    }
    return Math.min(1, near / 3);
  }

  function notchGlowVec(cycle) {
    const sides = [0, 0, 0, 0];
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const t = (cycle + i / PARTICLE_COUNT) % 1;
      if (t >= 0.50 && t <= 0.62) {
        const s = Math.sin(((t - 0.50) / 0.12) * Math.PI);
        sides[i % 4] = Math.max(sides[i % 4], s);
      }
    }
    return sides;
  }

  function emitWindow(cycle) {
    return (cycle >= 0.78 && cycle <= 1.0)
      ? Math.sin(((cycle - 0.78) / 0.22) * Math.PI)
      : 0;
  }

  // ===== The component =====

  /**
   * Stages (entrance — driven by elapsed time):
   *   0 blank
   *   1 bezel traces in     (0 → 450ms)
   *   2 monogram stamps     (450 → 800ms)
   *   3 ticks + ZK + hash   (800 → 1300ms)
   *   4 cycle alive         (1300ms+)  ← rAF loop begins
   */
  function LogoDeluxe({ size = 120, active = true }) {
    const [stage, setStage] = React.useState(0);
    const [cycle, setCycle] = React.useState(0);
    const idScope = React.useId ? React.useId().replace(/:/g, '') : 'xb-' + Math.random().toString(36).slice(2, 8);

    // Entrance stages
    React.useEffect(() => {
      if (!active) return;
      const timers = [
        setTimeout(() => setStage(1), 50),
        setTimeout(() => setStage(2), 450),
        setTimeout(() => setStage(3), 800),
        setTimeout(() => setStage(4), 1300),
      ];
      return () => timers.forEach(clearTimeout);
    }, [active]);

    // Agent cycle loop — 30 Hz, only after stage 4
    React.useEffect(() => {
      if (!active || stage < 4) return;
      const start = performance.now();
      let last = 0;
      let raf;
      const tick = (now) => {
        if (now - last >= 33) {
          last = now;
          setCycle(((now - start) % LOOP_MS) / LOOP_MS);
        }
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    }, [active, stage]);

    const gradId  = `${idScope}-g`;
    const lineId  = `${idScope}-line`;
    const haloId  = `${idScope}-halo`;
    const glowId  = `${idScope}-glow`;

    const showBezel = stage >= 1;
    const showMono  = stage >= 2;
    const showTicks = stage >= 3;
    const showZK    = stage >= 3;
    const showRcpt  = stage >= 3;
    const showLive  = stage >= 4;

    const compress  = showLive ? compressionIntensity(cycle) : 0;
    const notch     = showLive ? notchGlowVec(cycle) : [0, 0, 0, 0];
    const emit      = showLive ? emitWindow(cycle) : 0;

    const ticks = [32, 35, 38, 41, 44, 47, 50, 53, 56];

    return React.createElement(
      'div',
      {
        style: {
          position: 'relative',
          width: size,
          height: size,
          display: 'inline-block',
          lineHeight: 0,
          userSelect: 'none',
        },
      },
      React.createElement(
        motion.svg,
        {
          xmlns: 'http://www.w3.org/2000/svg',
          width: size,
          height: size,
          viewBox: '0 0 64 64',
          role: 'img',
          'aria-label': 'xB77 receipt seal',
          initial: { opacity: 0, scale: 0.96 },
          animate: { opacity: 1, scale: 1 },
          transition: { duration: 0.3, ease: 'easeOut' },
          style: { display: 'block', overflow: 'visible' },
        },
        // <defs>
        React.createElement(
          'defs',
          null,
          React.createElement(
            'linearGradient',
            { id: gradId, x1: '0', y1: '0', x2: '1', y2: '1' },
            React.createElement('stop', { offset: '0%',   stopColor: COLORS.lime }),
            React.createElement('stop', { offset: '55%',  stopColor: COLORS.midGreen }),
            React.createElement('stop', { offset: '100%', stopColor: COLORS.cyan })
          ),
          React.createElement(
            'linearGradient',
            { id: lineId, x1: '0', y1: '0', x2: '1', y2: '0' },
            React.createElement('stop', { offset: '0%',   stopColor: COLORS.cyan, stopOpacity: '0.35' }),
            React.createElement('stop', { offset: '100%', stopColor: COLORS.lime, stopOpacity: '0.35' })
          ),
          // Halo gradient — static stops; live opacity modulated on the <circle>
          React.createElement(
            'radialGradient',
            { id: haloId, cx: '0.5', cy: '0.5', r: '0.5' },
            React.createElement('stop', { offset: '0%',   stopColor: COLORS.lime, stopOpacity: '0.35' }),
            React.createElement('stop', { offset: '60%',  stopColor: COLORS.lime, stopOpacity: '0.10' }),
            React.createElement('stop', { offset: '100%', stopColor: COLORS.lime, stopOpacity: '0' })
          ),
          // Monogram glow filter
          React.createElement(
            'filter',
            { id: glowId, x: '-30%', y: '-30%', width: '160%', height: '160%' },
            React.createElement('feGaussianBlur', { in: 'SourceAlpha', stdDeviation: '0.6', result: 'blur' }),
            React.createElement('feFlood',        { floodColor: COLORS.lime, floodOpacity: '0.7', result: 'flood' }),
            React.createElement('feComposite',    { in: 'flood', in2: 'blur', operator: 'in', result: 'glow' }),
            React.createElement(
              'feMerge',
              null,
              React.createElement('feMergeNode', { in: 'glow' }),
              React.createElement('feMergeNode', { in: 'SourceGraphic' })
            )
          )
        ),

        // Plate
        React.createElement('rect', { width: 64, height: 64, rx: 10, fill: COLORS.bg }),

        // Compression halo (live)
        showLive && compress > 0.05 && React.createElement('circle', {
          cx: 32, cy: 36, r: 22,
          fill: `url(#${haloId})`,
          opacity: Math.min(1, compress * 1.4),
        }),

        // Bezel — chamfered double-rule (entrance via Framer Motion)
        React.createElement(motion.rect, {
          x: 3, y: 3, width: 58, height: 58, rx: 7,
          fill: 'none',
          stroke: `url(#${gradId})`,
          strokeWidth: 1.2,
          strokeDasharray: 232,
          initial: { strokeDashoffset: 232, opacity: 0 },
          animate: showBezel
            ? { strokeDashoffset: 0, opacity: 0.85 }
            : { strokeDashoffset: 232, opacity: 0 },
          transition: { duration: 0.6, ease: [0.16, 1, 0.3, 1] },
        }),

        // Bezel inner ghost
        React.createElement(motion.rect, {
          x: 5.5, y: 5.5, width: 53, height: 53, rx: 5.5,
          fill: 'none',
          stroke: COLORS.cyan,
          strokeWidth: 0.4,
          initial: { opacity: 0 },
          animate: { opacity: showBezel ? 0.22 : 0 },
          transition: { duration: 0.6, delay: 0.2 },
        }),

        // Notch glow markers (live)
        showLive && notch[0] > 0.05 && React.createElement('circle', {
          cx: 32, cy: 3, r: 0.9 + notch[0] * 0.8, fill: COLORS.lime, opacity: notch[0],
        }),
        showLive && notch[1] > 0.05 && React.createElement('circle', {
          cx: 61, cy: 32, r: 0.9 + notch[1] * 0.8, fill: COLORS.lime, opacity: notch[1],
        }),
        showLive && notch[2] > 0.05 && React.createElement('circle', {
          cx: 32, cy: 61, r: 0.9 + notch[2] * 0.8, fill: COLORS.lime, opacity: notch[2],
        }),
        showLive && notch[3] > 0.05 && React.createElement('circle', {
          cx: 3, cy: 32, r: 0.9 + notch[3] * 0.8, fill: COLORS.lime, opacity: notch[3],
        }),

        // Agent particles (live)
        showLive && React.createElement(
          'g',
          { 'aria-hidden': true },
          PARTICLES.map((p, i) => {
            const r = computeParticle(p, cycle);
            if (r.opacity < 0.02 || r.r < 0.05) return null;
            return React.createElement('circle', {
              key: i,
              cx: r.cx, cy: r.cy, r: r.r,
              fill: r.fill, opacity: r.opacity,
            });
          })
        ),

        // Monogram — entrance via Framer Motion, glow layer driven by compress
        React.createElement(
          motion.g,
          {
            initial: { opacity: 0, y: -6, scale: 0.92 },
            animate: showMono
              ? { opacity: 1, y: 0, scale: [0.92, 1.05, 1] }
              : { opacity: 0, y: -6, scale: 0.92 },
            transition: { duration: 0.32, ease: 'easeOut', times: [0, 0.7, 1] },
            style: { transformOrigin: '32px 36px', transformBox: 'fill-box' },
          },
          // Glow layer (live, fades in with compress)
          showLive && compress > 0.05 && React.createElement(
            'g',
            { filter: `url(#${glowId})`, opacity: Math.min(1, compress * 1.3) },
            React.createElement('text', {
              x: 32, y: 38, textAnchor: 'middle',
              fontFamily: "'Geist Mono', ui-monospace, 'JetBrains Mono', Menlo, monospace",
              fontWeight: 900, fontSize: 18, letterSpacing: '-1.2',
              fill: `url(#${gradId})`,
            }, 'xB77')
          ),
          React.createElement(
            'text',
            {
              x: 32, y: 38, textAnchor: 'middle',
              fontFamily: "'Geist Mono', ui-monospace, 'JetBrains Mono', Menlo, monospace",
              fontWeight: 900, fontSize: 18, letterSpacing: '-1.2',
              fill: `url(#${gradId})`,
            },
            'xB77'
          )
        ),

        // Receipt hash strip — entrance fade + live emit pulse
        React.createElement(
          motion.text,
          {
            x: 7.5, y: 58.5,
            fontFamily: "'Geist Mono', ui-monospace, monospace",
            fontSize: 2.6, fill: COLORS.cyan,
            letterSpacing: '0.4',
            initial: { opacity: 0 },
            animate: { opacity: showRcpt ? Math.min(1, 0.55 + emit * 0.45) : 0 },
            transition: { duration: 0.4 },
          },
          '0x77b…a9f'
        ),

        // Chronograph tick strip
        React.createElement(
          'g',
          { stroke: COLORS.lime, strokeWidth: 0.9, strokeLinecap: 'round' },
          ticks.map((x, i) =>
            React.createElement(motion.line, {
              key: x,
              x1: x,
              y1: i === 0 ? 56.5 : (i % 2 === 0 ? 57.5 : 58.0),
              x2: x,
              y2: 60.5,
              initial: { opacity: 0 },
              animate: { opacity: showTicks ? (i === 0 ? 0.9 : 0.65) : 0 },
              transition: { duration: 0.2, delay: 0.04 * i },
            })
          )
        ),

        // ZK ✓ badge — entrance
        React.createElement(
          motion.g,
          {
            initial: { opacity: 0, scale: 0.6, y: -2 },
            animate: showZK
              ? { opacity: 1, scale: [0.6, 1.05, 1], y: 0 }
              : { opacity: 0, scale: 0.6, y: -2 },
            transition: { duration: 0.35, ease: 'easeOut', times: [0, 0.7, 1] },
            style: { transformOrigin: '51px 11px', transformBox: 'fill-box' },
            transform: 'translate(44.5 7)',
          },
          React.createElement('rect', {
            width: 13, height: 8, rx: 1.5,
            fill: 'none', stroke: COLORS.lime, strokeWidth: 0.6, opacity: 0.85,
          }),
          React.createElement(
            'text',
            {
              x: 3.2, y: 5.8,
              fontFamily: "'Geist Mono', ui-monospace, monospace",
              fontWeight: 700, fontSize: 4.2, fill: COLORS.lime,
            },
            'ZK'
          ),
          React.createElement('path', {
            d: 'M8.4 4.3 L9.5 5.5 L11.2 3.2',
            stroke: COLORS.lime, strokeWidth: 0.8,
            strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none',
          })
        )
      )
    );
  }

  window.LogoDeluxe = LogoDeluxe;
})();
