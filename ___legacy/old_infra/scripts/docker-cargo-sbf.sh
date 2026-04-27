#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xb77-noir-sunspot:1.0.0-beta.13"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "No container runtime found." >&2
  exit 1
fi

# Ensure image exists (sunspot.sh handles build usually, but check here)
if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
   echo "Image ${IMAGE_NAME} not found. Running sunspot.sh help to trigger build..."
   "${ROOT_DIR}/scripts/sunspot.sh" help >/dev/null
fi

# Run cargo build-sbf inside container
# We need to install solana tools inside if they aren't there, OR rely on pre-installed ones.
# The Containerfile installs Rust but DOES NOT explicitely install Solana tools (cargo-build-sbf).
# Wait, standard rustup install does not include cargo-build-sbf. That comes with Solana CLI suite.

# Let's check Containerfile content again.
