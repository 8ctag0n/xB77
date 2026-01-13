#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CIRCUIT_DIR="${ROOT_DIR}/circuits/agent_badge"
SDK_ARTIFACT_DIR="${ROOT_DIR}/sdk/src/artifacts"

mkdir -p "${SDK_ARTIFACT_DIR}"

pushd "${CIRCUIT_DIR}" >/dev/null
nargo compile
popd >/dev/null

cp "${CIRCUIT_DIR}/target/agent_badge.json" "${SDK_ARTIFACT_DIR}/agent_badge.json"
echo "Wrote ${SDK_ARTIFACT_DIR}/agent_badge.json"
