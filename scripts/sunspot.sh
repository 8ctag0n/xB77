#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xb77-noir-sunspot:1.0.0-beta.13"
SOLANA_BIN_DIR=""

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
