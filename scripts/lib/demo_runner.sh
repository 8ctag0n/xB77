#!/usr/bin/env bash
# scripts/lib/demo_runner.sh — interactive step prompt
[[ -n "${_DEMO_RUNNER_LOADED:-}" ]] && return 0
_DEMO_RUNNER_LOADED=1

# Returns one of: run | skip | quit
# If user picks "all", flips global RUNNER=0 and returns "run".
# Reads from /dev/tty so it works even when stdin is redirected.
prompt_step() {
  local step_name="$1" desc="${2:-}"
  while true; do
    printf '\n%s%s%s\n' "$C_BOLD" "$step_name" "$C_RESET"
    [[ -n "$desc" ]] && printf '%s\n' "$desc"
    printf '%s[r]un  [s]kip  [a]ll  [c]md  [q]uit%s ' "$C_CYA" "$C_RESET"
    local choice
    if ! read -r -n 1 choice </dev/tty; then
      echo
      echo "quit"; return 0
    fi
    echo
    case "$choice" in
      r|R|"") echo "run"; return 0 ;;
      s|S)    echo "skip"; return 0 ;;
      a|A)    RUNNER=0; echo "run"; return 0 ;;
      q|Q)    echo "quit"; return 0 ;;
      c|C)    printf '%scmd:%s %s\n' "$C_YEL" "$C_RESET" "${STEP_CMD_PREVIEW:-<not set>}" ;;
      *)      printf '?? \n' ;;
    esac
  done
}
