#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VK_GEN_DIR="/app/scripts/vk-gen"
INPUT_VK="/app/circuits/agent_badge/target/agent_badge.vk"
OUTPUT_RS="/app/onchain/programs/xb77_gateway/src/badge_vk.rs"

# Ensure we are using the pinned image
IMAGE_NAME="xb77-noir-sunspot:1.0.0-beta.13"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found." >&2
  exit 1
fi

echo "Generating Rust verifier key..."
"${CONTAINER_CMD}" run --rm \
  --entrypoint /bin/bash \
  -v "${ROOT_DIR}:/app" \
  -w "${VK_GEN_DIR}" \
  "${IMAGE_NAME}" \
  -c "cargo run -- --input ${INPUT_VK} --output ${OUTPUT_RS}"
