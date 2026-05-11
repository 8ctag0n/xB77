#!/usr/bin/env bash
# Compile JSX sources → plain JS for the public webapp.
#
# Sources:    webapp_deploy/assets/src/*.jsx
# Output:     webapp_deploy/assets/js/*.js
#
# Each .jsx becomes a .js with React.createElement calls. No bundling,
# no module resolution — these scripts share globals (React, THEMES,
# useBreakpoint, etc.) and are loaded in order by index.html.
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

if [[ "${1:-}" == "--watch" ]]; then
  exec bunx esbuild "${ARGS[@]}" --watch
fi

bunx esbuild "${ARGS[@]}"
