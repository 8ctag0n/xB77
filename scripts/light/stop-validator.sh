#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [ ! -f "${LIGHT_COMPOSE_FILE}" ]; then
  echo "Missing compose file at ${LIGHT_COMPOSE_FILE}" >&2
  exit 1
fi

echo "Stopping Light devcontainer services via ${CONTAINER_CMD} compose"
"${CONTAINER_CMD}" compose -f "${LIGHT_COMPOSE_FILE}" down
