#!/usr/bin/env bash
# scripts/lib/demo_util.sh — shared helpers for demo_deluxe.sh
[[ -n "${_DEMO_UTIL_LOADED:-}" ]] && return 0
_DEMO_UTIL_LOADED=1

if [[ -t 1 ]]; then
  C_RESET=$(tput sgr0); C_BOLD=$(tput bold)
  C_RED=$(tput setaf 1); C_GRN=$(tput setaf 2)
  C_YEL=$(tput setaf 3); C_BLU=$(tput setaf 4); C_CYA=$(tput setaf 6)
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""
fi

log_info()  { printf '%s[INFO]%s  %s\n' "$C_BLU" "$C_RESET" "$*"; }
log_step()  { printf '\n%s──── %s ────%s\n' "$C_BOLD" "$*" "$C_RESET"; }
log_warn()  { printf '%s[WARN]%s  %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[ERR ]%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
log_ok()    { printf '%s[ OK ]%s  %s\n' "$C_GRN" "$C_RESET" "$*"; }

# run_cmd: prints the command, then executes (or skips if DRY_RUN=1).
# Use: run_cmd solana balance "$PUBKEY" --url devnet
run_cmd() {
  printf '%s$%s %s\n' "$C_CYA" "$C_RESET" "$*"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  "$@"
}

explorer_tx() {
  local sig="$1"
  printf '%s%s%s\n' "$C_GRN" "https://explorer.solana.com/tx/${sig}?cluster=${CLUSTER:-devnet}" "$C_RESET"
}

# require_image: fails loud if podman image absent locally
require_image() {
  local img="$1" containerfile="$2"
  if ! podman image exists "$img" 2>/dev/null; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_warn "image $img not present (would build: podman build -f $containerfile -t $img .)"
      return 0
    fi
    log_error "Missing podman image: $img"
    log_error "Build it:  podman build -f $containerfile -t $img ."
    return 1
  fi
}
