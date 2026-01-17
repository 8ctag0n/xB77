#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [ -d "${LIGHT_PROTOCOL_DIR}/.git" ]; then
  echo "Light Protocol repo already present at ${LIGHT_PROTOCOL_DIR}"
  exit 0
fi

mkdir -p "$(dirname "${LIGHT_PROTOCOL_DIR}")"

echo "Cloning Light Protocol repo into ${LIGHT_PROTOCOL_DIR}"

git clone https://github.com/Lightprotocol/light-protocol.git "${LIGHT_PROTOCOL_DIR}"

if [ -n "${LIGHT_PROTOCOL_REF:-}" ]; then
  echo "Checking out ref ${LIGHT_PROTOCOL_REF}"
  (cd "${LIGHT_PROTOCOL_DIR}" && git checkout "${LIGHT_PROTOCOL_REF}")
fi

echo "Done. You can now run: ${ROOT_DIR}/scripts/light/start-validator.sh"
