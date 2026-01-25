#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Gateway (Mollusk)
cargo test --manifest-path "${ROOT_DIR}/onchain/programs/xb77_gateway/Cargo.toml"

# Core
cargo test --manifest-path "${ROOT_DIR}/onchain/programs/xb77_core/Cargo.toml"

# Registry (if present)
cargo test --manifest-path "${ROOT_DIR}/onchain/programs/xb77_registry/Cargo.toml"
