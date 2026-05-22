#!/usr/bin/env bash
# Compile JSX sources → plain JS for the public webapp.
#
# Sources:    apps/web/assets/src/*.jsx       (JSX, esbuild-compiled)
#             apps/web/assets/src/lib/*.js    (plain JS, copied as-is)
# Output:     apps/web/assets/js/*.js
#             apps/web/assets/js/lib/*.js
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

copy_idls() {
  # The dApp loads IDL JSON via fetch (e.g. /idls/xb77.iopression.json).
  # Keep apps/web/idls/ in sync with the repo-root idls/.
  if [[ -d ../../idls ]]; then
    mkdir -p idls
    cp -f ../../idls/*.json idls/ 2>/dev/null || true
  fi
}

# Clean derived output so deleted sources don't leave orphan .js files.
# assets/js/ is fully regenerated from assets/src/ on every build.
clean_out() {
  rm -f assets/js/*.js
  rm -f assets/js/lib/*.js
}

if [[ "${1:-}" == "--watch" ]]; then
  clean_out
  copy_lib
  copy_idls
  exec bunx esbuild "${ARGS[@]}" --watch
fi

clean_out
bunx esbuild "${ARGS[@]}"
copy_lib
copy_idls
