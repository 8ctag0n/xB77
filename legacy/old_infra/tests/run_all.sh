#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/tests/sdk/run.sh"
"${ROOT_DIR}/tests/programs/run.sh"
"${ROOT_DIR}/tests/localnet/run.sh"
