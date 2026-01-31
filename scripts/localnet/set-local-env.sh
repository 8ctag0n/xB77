#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced (e.g. '. scripts/localnet/set-local-env.sh')." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"
PROGRAM_IDS_FILE="${ROOT_DIR}/.localnet/program_ids.env"

die() {
  echo "$@" >&2
  return 1
}

if [[ ! -f "${PROGRAM_IDS_FILE}" ]]; then
  die "Local program IDs not found. Run scripts/localnet/deploy-all.sh first."
fi

export SOLANA_RPC_URL="http://127.0.0.1:8899"
export XB77_LIGHT_RPC_URL="${SOLANA_RPC_URL}"
export XB77_LIGHT_COMPRESSION_RPC_URL="http://127.0.0.1:8784"
export XB77_LIGHT_PROVER_RPC_URL="http://127.0.0.1:3001"
export LIGHT_COMPRESSION_RPC_URL="${XB77_LIGHT_COMPRESSION_RPC_URL}"
export LIGHT_PROVER_RPC_URL="${XB77_LIGHT_PROVER_RPC_URL}"

while IFS= read -r line; do
  [[ -z "${line}" || "${line}" == \#* ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  case "${key}" in
    xb77_core_ID) export XB77_CORE_PROGRAM_ID="${value}" ;;
    xb77_gateway_ID) export XB77_GATEWAY_PROGRAM_ID="${value}" ;;
    xb77_registry_ID) export XB77_REGISTRY_PROGRAM_ID="${value}" ;;
    xb77_receipts_ID) export XB77_RECEIPTS_PROGRAM_ID="${value}" ;;
    xb77_test_utils_ID) export XB77_TEST_UTILS_PROGRAM_ID="${value}" ;;
  esac
done < "${PROGRAM_IDS_FILE}"

echo "[local-env] Loaded program IDs from ${PROGRAM_IDS_FILE}"
echo "[local-env] SOLANA_RPC_URL=${SOLANA_RPC_URL}"
echo "[local-env] Light compression RPC=${XB77_LIGHT_COMPRESSION_RPC_URL}, prover=${XB77_LIGHT_PROVER_RPC_URL}"
return 0
