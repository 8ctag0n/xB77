#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xb77-solana-builder:latest"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found." >&2
  exit 1
fi

# Build builder image if needed
if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Building builder image..."
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/containers/builder/Containerfile" "${ROOT_DIR}"
fi

echo "Compiling Verifier Program in Docker..."
"${CONTAINER_CMD}" run --rm \
  --entrypoint "" \
  -v "${ROOT_DIR}:/app" \
  -w "/app" \
  -e "RUST_LOG=info" \
  "${IMAGE_NAME}" \
  cargo build-sbf --manifest-path circuits/agent_badge/verifier_program/Cargo.toml --sbf-out-dir circuits/agent_badge/target/deploy

echo "Done."

