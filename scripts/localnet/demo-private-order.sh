#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cat <<'EOF'
This demo currently requires running steps separately.

1) scripts/localnet/verify-badge.sh
2) TOKEN_MINT=... RECIPIENT=... scripts/localnet/submit-private-order.sh
EOF
