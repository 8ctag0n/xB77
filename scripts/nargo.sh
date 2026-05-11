#!/usr/bin/env bash
# xB77 Nargo Wrapper - Run Noir commands in a container
# Replicable and isolated.

set -euo pipefail

IMAGE_NAME="xb77-zk:latest"
CONTAINER_CMD="podman"

if ! command -v podman >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_CMD="docker"
    else
        echo "Error: No container runtime (podman/docker) found."
        exit 1
    fi
fi

# If a --program-dir flag was passed (used by prover.zig to point at a specific
# circuits/<name>/ subdir), mount that dir as /app and pass the remaining args
# through. Otherwise mount the repo root and forward all args.
PROGRAM_DIR=""
FILTERED_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --program-dir) PROGRAM_DIR="$2"; shift 2 ;;
    *)             FILTERED_ARGS+=("$1"); shift ;;
  esac
done

if [[ -n "$PROGRAM_DIR" ]]; then
    ABS_DIR="$(cd "$PROGRAM_DIR" && pwd)"
    ${CONTAINER_CMD} run --rm \
        -v "$ABS_DIR:/app:Z" \
        -w "/app" \
        "${IMAGE_NAME}" \
        "${FILTERED_ARGS[@]}"
else
    ${CONTAINER_CMD} run --rm \
        -v "$(pwd):/app:Z" \
        -w "/app" \
        "${IMAGE_NAME}" \
        "${FILTERED_ARGS[@]}"
fi
