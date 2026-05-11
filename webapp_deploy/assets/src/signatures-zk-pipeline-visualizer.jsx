/* xB77 Signature Component — ZK Pipeline Visualizer
 *
 * 5 SVG nodes: AGENT → PROOF_GEN → CHUNK_UPLOAD → VERIFY → SETTLED
 * Cyan "packet" pulse traverses node-to-node every ~9s, drop-shadow trail.
 *
 * Props:
 *   variant   'compact' (home) | 'expanded' (architecture)   default 'compact'
 *   liveData  optional { [stage]: { count, latencyMs, chunkBytes } } | null
 *   theme     optional theme object (uses obsidian fallback)
 *
 * Exports: window.ZKPipelineVisualizer
 */

(function () {
  const STAGES = [
    { id: 'AGENT',        label: 'Agent',        contract: 'neural_key.sol',  hint: 'Sign intent' },
    { id: 'PROOF_GEN',    label: 'Proof Gen',    contract: 'xb77_zk_engine',  hint: 'SNARK build' },
    { id: 'CHUNK_UPLOAD', label: 'Chunk Upload', contract: 'sframe.upload',   hint: 'Compress + push' },
    { id: 'VERIFY',       label: 'Verify',       contract: 'verifier_stub',   hint: 'On-chain check' },
    { id: 'SETTLED',      label: 'Settled',      contract: 'magicblock.tx',   hint: '< 1s finality' },
  ];

  const COLORS = {
    bg:      '#0a0a0c',
    nodeBg:  '#101013',
    border:  'rgba(255,255,255,0.10)',
    lime:    '#c8ff2e',
    cyan:    '#5cf2ff',
    text:    '#e8e8ec',
    textDim: 'rgba(232,232,236,0.55)',
    mono:    'rgba(232,232,236,0.35)',
  };

  const CYCLE_MS = 9000;

  function usePulseProgress(cycleMs) {
    const [t, setT] = React.useState(0);
    React.useEffect(() => {
      let raf, start;
      const tick = (now) => {
        if (start == null) start = now;
        const p = ((now - start) % cycleMs) / cycleMs;
        setT(p);
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    }, [cycleMs]);
    return t;
  }

  function ZKPipelineVisualizer(props) {
    const variant = props.variant || 'compact';
    const liveData = props.liveData || null;
    const expanded = variant === 'expanded';

    const t = usePulseProgress(CYCLE_MS);

    // Layout
    const N = STAGES.length;
    const W = expanded ? 1100 : 720;
    const H = expanded ? 260 : 160;
    const padX = 60;
    const innerW = W - padX * 2;
    const stepX = innerW / (N - 1);
    const cy = expanded ? 130 : 80;
    const r = expanded ? 26 : 20;

    // Packet position
    const segCount = N - 1;
    const segT = t * segCount;
    const segIdx = Math.floor(segT) % segCount;
    const segLocal = segT - Math.floor(segT);
    // ease in/out so it lingers near nodes
    const eased = segLocal < 0.5
      ? 2 * segLocal * segLocal
      : 1 - Math.pow(-2 * segLocal + 2, 2) / 2;
    const packetX = padX + segIdx * stepX + eased * stepX;
    const packetY = cy;

    // Which node is "active" — lights up lime as packet arrives
    const arrivalWindow = 0.15;
    const nearTarget = segLocal > (1 - arrivalWindow);
    const activeIdx = nearTarget ? (segIdx + 1) % N : segIdx;
    const pulseStrength = nearTarget ? (segLocal - (1 - arrivalWindow)) / arrivalWindow : 0;

    return (
      <div style={{
        width: '100%',
        background: 'transparent',
        overflowX: 'auto',
        padding: expanded ? '24px 0' : '12px 0',
      }}>
        <svg
          viewBox={`0 0 ${W} ${H}`}
          width="100%"
          style={{ display: 'block', maxWidth: W, margin: '0 auto', minWidth: 560 }}
          aria-label="xB77 ZK Pipeline"
        >
          <defs>
            <filter id="zkGlowCyan" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="3.2" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
            <filter id="zkGlowLime" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="2.5" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
            <linearGradient id="zkTrail" x1="0" x2="1" y1="0" y2="0">
              <stop offset="0%" stopColor={COLORS.cyan} stopOpacity="0" />
              <stop offset="100%" stopColor={COLORS.cyan} stopOpacity="0.7" />
            </linearGradient>
          </defs>

          {/* connector line */}
          <line
            x1={padX} y1={cy} x2={W - padX} y2={cy}
            stroke={COLORS.border} strokeWidth="1"
            strokeDasharray="2 4"
          />

          {/* trail behind packet */}
          <rect
            x={Math.max(padX, packetX - 60)}
            y={cy - 1}
            width={Math.min(60, packetX - padX)}
            height={2}
            fill="url(#zkTrail)"
          />

          {/* packet */}
          <circle
            cx={packetX} cy={packetY} r={5}
            fill={COLORS.cyan}
            filter="url(#zkGlowCyan)"
          />

          {/* nodes */}
          {STAGES.map((s, i) => {
            const x = padX + i * stepX;
            const isActive = i === activeIdx;
            const intensity = isActive ? Math.max(0.4, pulseStrength) : 0;
            const ringColor = isActive ? COLORS.lime : COLORS.border;
            const fillColor = COLORS.nodeBg;
            const live = liveData && liveData[s.id];

            return (
              <g key={s.id}>
                {/* node ring */}
                <circle
                  cx={x} cy={cy} r={r}
                  fill={fillColor}
                  stroke={ringColor}
                  strokeWidth={isActive ? 2 : 1}
                  filter={isActive ? 'url(#zkGlowLime)' : undefined}
                  opacity={isActive ? 0.6 + 0.4 * intensity : 1}
                />
                <circle
                  cx={x} cy={cy} r={r - 6}
                  fill="none"
                  stroke={isActive ? COLORS.lime : COLORS.mono}
                  strokeWidth="1"
                  opacity={isActive ? intensity : 0.35}
                />
                {/* stage index */}
                <text
                  x={x} y={cy + 4}
                  textAnchor="middle"
                  fontFamily="var(--mono, monospace)"
                  fontSize={expanded ? 12 : 10}
                  fontWeight="600"
                  fill={isActive ? COLORS.lime : COLORS.text}
                  opacity={isActive ? 1 : 0.85}
                >
                  {String(i + 1).padStart(2, '0')}
                </text>

                {/* label below */}
                <text
                  x={x} y={cy + r + 18}
                  textAnchor="middle"
                  fontFamily="var(--mono, monospace)"
                  fontSize={expanded ? 11 : 9.5}
                  fill={COLORS.textDim}
                  letterSpacing="0.12em"
                >
                  {s.label.toUpperCase()}
                </text>

                {/* live count above (expanded variant) */}
                {expanded && live && (
                  <text
                    x={x} y={cy - r - 14}
                    textAnchor="middle"
                    fontFamily="var(--mono, monospace)"
                    fontSize="13"
                    fontWeight="600"
                    fill={COLORS.cyan}
                  >
                    {typeof live.count === 'number' ? live.count.toLocaleString() : (live.count || '—')}
                  </text>
                )}
                {expanded && live && (
                  <text
                    x={x} y={cy - r - 30}
                    textAnchor="middle"
                    fontFamily="var(--mono, monospace)"
                    fontSize="9"
                    fill={COLORS.mono}
                    letterSpacing="0.15em"
                  >
                    {live.latencyMs != null ? `P50 ${live.latencyMs}ms` : ''}
                  </text>
                )}
              </g>
            );
          })}
        </svg>

        {/* expanded mini-cards */}
        {expanded && (
          <div style={{
            display: 'grid',
            gridTemplateColumns: `repeat(${N}, 1fr)`,
            gap: 8,
            maxWidth: W,
            margin: '20px auto 0',
            padding: '0 16px',
          }}>
            {STAGES.map((s, i) => {
              const live = liveData && liveData[s.id];
              return (
                <div key={s.id} style={{
                  border: `1px solid ${COLORS.border}`,
                  padding: '12px 14px',
                  background: 'rgba(255,255,255,0.015)',
                }}>
                  <div style={{
                    fontFamily: 'var(--mono, monospace)',
                    fontSize: 9, color: COLORS.lime,
                    letterSpacing: '0.15em', marginBottom: 6,
                  }}>{String(i + 1).padStart(2, '0')} · {s.label.toUpperCase()}</div>
                  <div style={{
                    fontFamily: 'var(--mono, monospace)',
                    fontSize: 11, color: COLORS.text, marginBottom: 4,
                  }}>{s.contract}</div>
                  <div style={{
                    fontFamily: 'var(--sans, system-ui)',
                    fontSize: 11, color: COLORS.textDim, lineHeight: 1.5,
                  }}>{s.hint}</div>
                  {live && live.chunkBytes != null && (
                    <div style={{
                      marginTop: 8,
                      fontFamily: 'var(--mono, monospace)',
                      fontSize: 10, color: COLORS.cyan,
                    }}>chunk {live.chunkBytes}B</div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  }

  window.ZKPipelineVisualizer = ZKPipelineVisualizer;
})();
