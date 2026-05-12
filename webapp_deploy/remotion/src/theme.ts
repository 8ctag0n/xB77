/**
 * xB77 brand tokens — single source of truth for all Remotion compositions
 * and the static SVG / Framer Motion mirrors in webapp_deploy/assets/.
 *
 * Keep this file in sync with webapp_deploy/assets/css/tokens.css.
 */
import { loadFont as loadGeistMono } from "@remotion/google-fonts/GeistMono";
import { loadFont as loadDMSans } from "@remotion/google-fonts/DMSans";
import { loadFont as loadInstrumentSerif } from "@remotion/google-fonts/InstrumentSerif";

export const COLORS = {
  bg:        "#08080a", // plate
  lime:      "#c8ff2e", // primary accent: verification
  cyan:      "#00f0ff", // secondary linework
  midGreen:  "#7fe6a8", // gradient midpoint
  textHi:    "#f4f4f5",
  textDim:   "#a1a1aa",
  rule:      "#52525b",
} as const;

// Load Google Fonts at module init so they're available before first render.
// loadFont() returns `{ fontFamily }` synchronously; the actual font fetch is
// tracked via Remotion's delayRender, so renders wait for it.
const geistMono       = loadGeistMono("normal",       { weights: ["700", "900"] });
const dmSans          = loadDMSans("normal",          { weights: ["400", "700"] });
const instrumentSerif = loadInstrumentSerif("italic", { weights: ["400"] });

export const FONTS = {
  mono:  `'${geistMono.fontFamily}', ui-monospace, 'JetBrains Mono', Menlo, monospace`,
  sans:  `'${dmSans.fontFamily}', system-ui, -apple-system, sans-serif`,
  serif: `'${instrumentSerif.fontFamily}', 'Iowan Old Style', Georgia, serif`,
} as const;

export const FPS = 30;
