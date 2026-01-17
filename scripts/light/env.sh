#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIGHT_PROTOCOL_DIR="${LIGHT_PROTOCOL_DIR:-${ROOT_DIR}/private/toolchains/light-protocol}"
LIGHT_COMPOSE_FILE="${LIGHT_COMPOSE_FILE:-${LIGHT_PROTOCOL_DIR}/.devcontainer/docker-compose.yml}"

export LIGHT_PROTOCOL_DIR
export LIGHT_COMPOSE_FILE

echo "LIGHT_PROTOCOL_DIR=${LIGHT_PROTOCOL_DIR}"
echo "LIGHT_COMPOSE_FILE=${LIGHT_COMPOSE_FILE}"
