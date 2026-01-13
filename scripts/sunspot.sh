#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xb77-noir-sunspot:0.36.0"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found. Install podman or docker." >&2
  exit 1
fi

if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/Containerfile.sunspot" "${ROOT_DIR}"
fi

"${CONTAINER_CMD}" run --rm \
  -v "${ROOT_DIR}:/app" \
  -w "/app" \
  "${IMAGE_NAME}" \
  sunspot "$@"
