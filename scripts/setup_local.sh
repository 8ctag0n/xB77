#!/usr/bin/env bash
# scripts/setup_local.sh — install all xB77 local dev dependencies
#
# Installs:
#   - Foundry (forge, cast, anvil)
#   - cargo-stylus (Arbitrum Stylus WASM deployer)
#   - Nargo (Noir ZK compiler + prover) — via noirup
#   - Docker + docker-compose (if not present)
#
# Usage:
#   scripts/setup_local.sh            # install everything
#   scripts/setup_local.sh --check    # verify what's installed
#   scripts/setup_local.sh --foundry  # only Foundry
#   scripts/setup_local.sh --stylus   # only cargo-stylus
#   scripts/setup_local.sh --nargo    # only Nargo/Noir

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'
BLD=$'\033[1m'; RST=$'\033[0m'
ok()   { printf "  ${GRN}✔${RST} %s\n" "$*"; }
warn() { printf "  ${YLW}⚠${RST} %s\n" "$*"; }
fail() { printf "  ${RED}✘${RST} %s\n" "$*" >&2; }
step() { printf "\n${BLU}${BLD}▶ %s${RST}\n" "$*"; }

# ── Parse args ────────────────────────────────────────────────────────────────
DO_FOUNDRY=1; DO_STYLUS=1; DO_NARGO=1; DO_DOCKER=1; CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --foundry) DO_FOUNDRY=1; DO_STYLUS=0; DO_NARGO=0; DO_DOCKER=0 ;;
    --stylus)  DO_FOUNDRY=0; DO_STYLUS=1; DO_NARGO=0; DO_DOCKER=0 ;;
    --nargo)   DO_FOUNDRY=0; DO_STYLUS=0; DO_NARGO=1; DO_DOCKER=0 ;;
    --check)   CHECK_ONLY=1 ;;
    -h|--help) sed -n '1,20p' "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
  esac
done

# ── Check mode ────────────────────────────────────────────────────────────────
check_tool() {
  local name="$1" cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$name: $(command -v "$cmd") — $($cmd --version 2>&1 | head -1)"
  else
    warn "$name: not found"
  fi
}

if (( CHECK_ONLY )); then
  step "Checking installed tools"
  check_tool "zig"          "zig"
  check_tool "forge"        "forge"
  check_tool "cast"         "cast"
  check_tool "anvil"        "anvil"
  check_tool "cargo"        "cargo"
  check_tool "cargo-stylus" "cargo-stylus"
  check_tool "nargo"        "nargo"
  check_tool "docker"       "docker"
  check_tool "bun"          "bun"
  exit 0
fi

# ── Foundry (forge, cast, anvil) ──────────────────────────────────────────────
if (( DO_FOUNDRY )); then
  step "Installing Foundry"
  if command -v forge >/dev/null 2>&1; then
    ok "forge already installed: $(forge --version 2>&1 | head -1)"
  else
    curl -L https://foundry.paradigm.xyz | bash
    # foundryup adds itself to PATH via ~/.bashrc; source it if needed
    export PATH="$HOME/.foundry/bin:$PATH"
    foundryup
    ok "Foundry installed: $(forge --version 2>&1 | head -1)"
  fi
fi

# ── cargo-stylus ─────────────────────────────────────────────────────────────
if (( DO_STYLUS )); then
  step "Installing cargo-stylus"
  if ! command -v cargo >/dev/null 2>&1; then
    warn "cargo not found — installing Rust toolchain first"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"
  fi

  if cargo stylus --version >/dev/null 2>&1; then
    ok "cargo-stylus already installed: $(cargo stylus --version 2>&1)"
  else
    cargo install cargo-stylus
    # Install wasm target for Stylus
    rustup target add wasm32-unknown-unknown
    ok "cargo-stylus installed: $(cargo stylus --version 2>&1)"
  fi
fi

# ── Nargo / Noir ──────────────────────────────────────────────────────────────
if (( DO_NARGO )); then
  step "Installing Nargo (Noir ZK compiler)"
  if command -v nargo >/dev/null 2>&1; then
    ok "nargo already installed: $(nargo --version 2>&1 | head -1)"
  else
    # noirup is the official Noir installer
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
    export PATH="$HOME/.nargo/bin:$PATH"
    noirup
    ok "nargo installed: $(nargo --version 2>&1 | head -1)"
  fi
fi

# ── Docker check ─────────────────────────────────────────────────────────────
if (( DO_DOCKER )); then
  step "Checking Docker"
  if command -v docker >/dev/null 2>&1; then
    ok "docker: $(docker --version 2>&1)"
    if docker compose version >/dev/null 2>&1; then
      ok "docker compose: $(docker compose version 2>&1)"
    else
      warn "docker compose plugin not found — install docker compose v2"
    fi
  else
    warn "Docker not found. Install from https://docs.docker.com/get-docker/"
    warn "Needed for: docker compose up nitro (Arbitrum local node)"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n${BLD}Setup complete.${RST}\n"
printf "  Next: ${GRN}docker compose up -d nitro${RST} to start the Arbitrum local node\n"
printf "  Then: ${GRN}scripts/e2e_zk_stylus.sh${RST} to deploy and test ZK contracts\n\n"
