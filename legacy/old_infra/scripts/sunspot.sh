#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xb77-noir-sunspot:1.0.0-beta.13"
SOLANA_BIN_DIR=""

print_help() {
  cat <<'EOF'
Usage:
  scripts/sunspot.sh [command...]
  scripts/sunspot.sh --list
  scripts/sunspot.sh compile
  scripts/sunspot.sh execute

What it does:
  Runs a Sunspot/Noir container with the repo mounted at /app.
  Any command you pass is executed inside the container.

Common commands:
  scripts/sunspot.sh nargo --version
  scripts/sunspot.sh nargo test -p circuits/agent_badge
  scripts/sunspot.sh nargo compile -p circuits/agent_badge
  scripts/sunspot.sh nargo execute -p circuits/agent_badge
  scripts/sunspot.sh bash -lc "ls -la /app/circuits/agent_badge"

Shortcuts:
  scripts/sunspot.sh compile   # calls scripts/noir-compile-sunspot.sh
  scripts/sunspot.sh execute   # calls scripts/noir-execute-sunspot.sh

Related helper scripts:
  scripts/noir-compile-sunspot.sh
  scripts/noir-execute-sunspot.sh
  scripts/build-noir-artifacts.sh

Tip:
  If you want to use a specific container runtime, set CONTAINER_CMD:
    CONTAINER_CMD=podman scripts/sunspot.sh nargo --version
EOF
}

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found. Install podman or docker." >&2
  exit 1
fi

if command -v solana >/dev/null 2>&1; then
  SOLANA_BIN_DIR="$(dirname "$(command -v solana)")"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" || "$#" -eq 0 ]]; then
  print_help
  exit 0
fi

if [[ "${1:-}" == "--list" ]]; then
  echo "Actions:"
  echo "  compile  -> scripts/noir-compile-sunspot.sh"
  echo "  execute  -> scripts/noir-execute-sunspot.sh"
  echo "  help     -> usage and examples"
  exit 0
fi

if [[ "${1:-}" == "compile" ]]; then
  shift
  exec "${ROOT_DIR}/scripts/noir-compile-sunspot.sh" "$@"
fi

if [[ "${1:-}" == "execute" ]]; then
  shift
  exec "${ROOT_DIR}/scripts/noir-execute-sunspot.sh" "$@"
fi

if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/containers/sunspot/Containerfile" "${ROOT_DIR}"
fi

"${CONTAINER_CMD}" run --rm \
  -v "${ROOT_DIR}:/app" \
  -w "/app" \
  ${SOLANA_BIN_DIR:+-v "${SOLANA_BIN_DIR}:/opt/solana/bin"} \
  -e "PATH=/opt/solana/bin:/root/.cargo/bin:/usr/local/go/bin:/root/.nargo/bin:/root/sunspot/go:/usr/bin:/bin" \
  "${IMAGE_NAME}" \
  "$@"
