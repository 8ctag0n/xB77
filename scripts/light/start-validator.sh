#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [ ! -d "${LIGHT_PROTOCOL_DIR}/.devcontainer" ]; then
  echo "Missing Light Protocol repo at ${LIGHT_PROTOCOL_DIR}." >&2
  echo "Run: ${ROOT_DIR}/scripts/light/bootstrap.sh" >&2
  exit 1
fi

if [ ! -f "${LIGHT_COMPOSE_FILE}" ]; then
  echo "Missing compose file at ${LIGHT_COMPOSE_FILE}" >&2
  exit 1
fi

echo "Starting Light devcontainer services via ${CONTAINER_CMD} compose"
"${CONTAINER_CMD}" compose -f "${LIGHT_COMPOSE_FILE}" up -d

echo "Light dev environment is starting. Use '${CONTAINER_CMD} compose -f ${LIGHT_COMPOSE_FILE} ps' to check status."
