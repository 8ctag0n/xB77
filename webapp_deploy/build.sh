#!/usr/bin/env bash
# Compile JSX sources → plain JS for the public webapp.
#
# Sources:    webapp_deploy/assets/src/*.jsx       (JSX, esbuild-compiled)
#             webapp_deploy/assets/src/lib/*.js    (plain JS, copied as-is)
# Output:     webapp_deploy/assets/js/*.js
#             webapp_deploy/assets/js/lib/*.js
#
# Each .jsx becomes a .js with React.createElement calls. No bundling,
# no module resolution — these scripts share globals (React, THEMES,
# useBreakpoint, D, etc.) and are loaded in order by index.html.
#
# Files under src/lib/ are vanilla JS (no JSX); they get copied verbatim
# to assets/js/lib/. Use this for non-React glue like data-source.js.
#
# Usage:
#   ./build.sh           one-shot build
#   ./build.sh --watch   rebuild on save
set -euo pipefail
cd "$(dirname "$0")"

ARGS=(
  assets/src/*.jsx
  --outdir=assets/js
  --loader:.jsx=jsx
  --jsx-factory=React.createElement
  --jsx-fragment=React.Fragment
  --target=es2020
  --out-extension:.js=.js
)

copy_lib() {
  if [[ -d assets/src/lib ]]; then
    mkdir -p assets/js/lib
    cp -f assets/src/lib/*.js assets/js/lib/ 2>/dev/null || true
  fi
}

if [[ "${1:-}" == "--watch" ]]; then
  copy_lib
  exec bunx esbuild "${ARGS[@]}" --watch
fi

bunx esbuild "${ARGS[@]}"
copy_lib
