#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CIRCUIT_DIR="${ROOT_DIR}/circuits/agent_badge"
SDK_ARTIFACT_DIR="${ROOT_DIR}/sdk/src/artifacts"
IMAGE_NAME="xb77-noir:0.36.0"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found. Install podman or docker." >&2
  exit 1
fi

mkdir -p "${SDK_ARTIFACT_DIR}"

if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/Containerfile" "${ROOT_DIR}"
fi

"${CONTAINER_CMD}" run --rm \
  -v "${ROOT_DIR}:/app" \
  -w "/app/circuits/agent_badge" \
  "${IMAGE_NAME}" \
  compile

cp "${CIRCUIT_DIR}/target/agent_badge.json" "${SDK_ARTIFACT_DIR}/agent_badge.json"
echo "Wrote ${SDK_ARTIFACT_DIR}/agent_badge.json"
