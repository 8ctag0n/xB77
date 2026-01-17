#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIGHT_PROTOCOL_DIR="${LIGHT_PROTOCOL_DIR:-${ROOT_DIR}/private/toolchains/light-protocol}"
LIGHT_COMPOSE_FILE="${LIGHT_COMPOSE_FILE:-${LIGHT_PROTOCOL_DIR}/.devcontainer/docker-compose.yml}"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found. Install podman or docker." >&2
  exit 1
fi

export ROOT_DIR
export LIGHT_PROTOCOL_DIR
export LIGHT_COMPOSE_FILE
export CONTAINER_CMD
