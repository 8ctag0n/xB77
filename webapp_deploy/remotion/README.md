# xB77 — Brand Remotion

Single source of truth for the xB77 receipt-seal mark, wordmark, hero loop, and
launch intro. Same React components drive **every** brand surface — favicon-grade
PNG, social preview card, web hero animation, and the hackathon pitch video.

The site (`webapp_deploy/`) does **not** depend on this project at runtime.
Instead, the static SVG (`assets/logo-deluxe.svg`, `assets/logo-og.svg`) and the
Framer Motion mirror (`assets/src/signatures-logo-deluxe.jsx`) are hand-emitted
copies of the Remotion source. Edit here, regenerate there — see *Sync* below.

## Why

The brief: a seal that gets *stamped* on every machine-to-machine payment.
Form follows product. Not generic cyberpunk noise — a verifiable, infrastructural
mark. Vocabulary: chamfered bezel, monogram, ZK ✓ badge, chronograph ticks,
commitment hash strip. Two-color discipline (lime → cyan), no magenta.

## Setup

```bash
cd webapp_deploy/remotion
npm install
```

## Compositions

| ID            | Size       | Frames | Output             | Deploy target                            |
| ------------- | ---------- | ------ | ------------------ | ---------------------------------------- |
| `MarkStatic`  | 512×512    | 1      | PNG                | favicon high-res, nav fallback, press kit |
| `WordmarkOG`  | 1200×630   | 1      | PNG                | `<meta property="og:image">`             |
| `HeroLoop`    | 800×300    | 180    | MP4 (seamless 6s)  | landing hero strip (optional)            |
| `LogoIntro`   | 1920×1080  | 90     | MP4 (3s stamp)     | hackathon pitch video opener             |

## Render

```bash
# Studio (interactive preview, hot-reload)
npm run studio

# One-shot exports
npm run render:mark    # → out/mark.png
npm run render:og      # → out/og.png
npm run render:hero    # → out/hero.mp4
npm run render:intro   # → out/intro.mp4
npm run render:all     # all four

# Per-frame PNG from any composition
npx remotion render LogoIntro out/intro-frame.png --frame=45 --image-format=png
```

## Files

```
src/
  theme.ts                       brand tokens (colors, fonts) — keep in sync with assets/css/tokens.css
  components/
    Seal.tsx                     the core mark; takes progress 0→1
    Wordmark.tsx                 "xB77" lockup with under-rule
  compositions/
    MarkStatic.tsx               single-frame square seal
    WordmarkOG.tsx               1200×630 social card
    HeroLoop.tsx                 6s seamless loop
    LogoIntro.tsx                3s stamp animation
  Root.tsx                       composition registry
  index.ts                       remotion entry
```

## Sync to webapp_deploy

When you change the Seal design:

1. Edit `src/components/Seal.tsx` (canonical source).
2. Mirror to the static SVG: regenerate `webapp_deploy/assets/logo-deluxe.svg`
   by either (a) hand-translating the JSX → SVG, or (b) `npx remotion render
   MarkStatic out/mark.svg --image-format=svg` once the SVG exporter is wired up.
3. Mirror to the runtime component: `webapp_deploy/assets/src/signatures-logo-deluxe.jsx`
   is a React.createElement port of the same JSX; copy the structure 1-for-1
   and update `webapp_deploy/assets/js/signatures-logo-deluxe.js` (currently
   just `cp` of the .jsx, since no build step is wired up).
4. Re-render the OG PNG and update `webapp_deploy/assets/logo-og.png` (or set
   `og:image` to point at `logo-og.svg` if your target platforms accept it —
   X / Twitter does not, LinkedIn does).

## Hackathon submission notes

`LogoIntro` is built to be the cold open for the pitch video. The 3s cadence is
deliberate — long enough to feel intentional, short enough that judges don't
fast-forward. Drop into a 60s submission as the first 3 seconds, then cut to
the demo.

`WordmarkOG` is the press-kit / share-card image. Render it to PNG and reference
it from the README of every public repo (xB77 monorepo, SDK, gateway).
