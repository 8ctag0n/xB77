#!/usr/bin/env bash
set -e

# xB77 CLI Release Bundle Script
# Compiles for Linux, macOS, and Windows.

VERSION="0.11.0-Sovereign"
DIST_DIR="dist"

echo "[RELEASE] Starting xB77 CLI build for version $VERSION..."

rm -rf $DIST_DIR
mkdir -p $DIST_DIR

# 1. Linux x64 (Production Target)
echo "[RELEASE] Building for Linux x64..."
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSmall
tar -czf $DIST_DIR/xb77-$VERSION-linux-x64.tar.gz -C zig-out/bin xb77

# 2. Source Bundle
echo "[RELEASE] Bundling Source Code..."
tar -czf $DIST_DIR/xb77-$VERSION-source.tar.gz \
    --exclude=".git" --exclude=".zig-cache" --exclude="zig-out" \
    --exclude="dist" --exclude="node_modules" .

echo "[RELEASE] Build complete! Assets in /$DIST_DIR"
ls -lh $DIST_DIR
