#!/bin/bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/.localnet/tools"
IDL_DIR="$ROOT/idls"

mkdir -p "$TOOLS_DIR" "$IDL_DIR"
export PATH="$TOOLS_DIR/bin:$PATH"

# Install shank if missing
if ! command -v shank >/dev/null; then
    echo "Installing shank-cli (this might take a minute)..."
    cargo install shank-cli --root "$TOOLS_DIR" --version 0.4.2 --quiet
fi

generate_idl() {
    local program_dir="$1"
    local program_name=$(basename "$program_dir")
    
    echo "Processing $program_name..."
    if [ -d "$program_dir" ]; then
        pushd "$program_dir" >/dev/null
        # Ensure Cargo.lock exists and dependencies are resolved
        cargo check --quiet
        shank idl --out-dir "$IDL_DIR" --crate-root .
        popd >/dev/null
        echo "  [OK] Generated $IDL_DIR/$program_name.json"
    else
        echo "  [SKIP] Directory not found: $program_dir"
    fi
}

echo "--- Generating IDLs ---"
generate_idl "$ROOT/onchain/programs/xb77_receipts"

# Future: Add xb77_core and xb77_gateway once instrumented
# generate_idl "$ROOT/onchain/programs/xb77_core"
# generate_idl "$ROOT/onchain/programs/xb77_gateway"

echo "-----------------------"
ls -l "$IDL_DIR"
