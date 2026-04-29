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

# Run nargo with the current directory mounted
# We mount the root of the repo so relative paths work if needed
# but we set the working directory to the current one.
${CONTAINER_CMD} run --rm \
    -v "$(pwd):/app:Z" \
    -w "/app" \
    "${IMAGE_NAME}" \
    "$@"
