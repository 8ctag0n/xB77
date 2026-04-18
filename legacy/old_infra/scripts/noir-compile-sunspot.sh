#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CIRCUIT_DIR="${ROOT_DIR}/circuits/agent_badge"
IMAGE_NAME="xb77-noir-sunspot:1.0.0-beta.13"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found. Install podman or docker." >&2
  exit 1
fi

if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/containers/sunspot/Containerfile" "${ROOT_DIR}"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/src"
cp "${CIRCUIT_DIR}/Nargo.toml" "${TMP_DIR}/Nargo.toml"
cp -R "${CIRCUIT_DIR}/src/." "${TMP_DIR}/src/"

"${CONTAINER_CMD}" run --rm \
  --entrypoint nargo \
  -v "${TMP_DIR}:/app" \
  -w "/app" \
  "${IMAGE_NAME}" \
  compile

mkdir -p "${CIRCUIT_DIR}/target"
cp "${TMP_DIR}/target/agent_badge.json" "${CIRCUIT_DIR}/target/agent_badge.json"
