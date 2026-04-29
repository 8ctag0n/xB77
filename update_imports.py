import os
import re

mappings = {
    "crypto.zig": "crypto/crypto.zig",
    "bn254.zig": "crypto/bn254.zig",
    "poseidon.zig": "crypto/poseidon.zig",
    "poseidon_constants.zig": "crypto/poseidon_constants.zig",
    "cmt.zig": "state/cmt.zig",
    "store.zig": "state/store.zig",
    "vault.zig": "state/vault.zig",
    "compression.zig": "state/compression.zig",
    "http.zig": "net/http.zig",
    "mesh.zig": "net/mesh.zig",
    "znode_bridge.zig": "net/znode_bridge.zig",
    "yellowstone.zig": "net/yellowstone.zig",
    "ipfs.zig": "net/ipfs.zig",
    "solana.zig": "chain/solana.zig",
    "evm.zig": "chain/evm.zig",
    "chain.zig": "chain/chain.zig",
    "anchor.zig": "chain/anchor.zig",
    "awp.zig": "protocol/awp.zig",
    "awpool.zig": "protocol/awpool.zig",
    "tx.zig": "protocol/tx.zig",
    "types.zig": "protocol/types.zig",
    "parser.zig": "protocol/parser.zig",
    "rlp.zig": "protocol/rlp.zig",
    "engine.zig": "engine/engine.zig",
    "context.zig": "engine/context.zig",
    "config.zig": "engine/config.zig",
    "strategist.zig": "engine/strategist.zig",
    "prover.zig": "engine/prover.zig",
    "merchant.zig": "business/merchant.zig",
    "pay.zig": "business/pay.zig",
    "receipt.zig": "business/receipt.zig",
    "swap.zig": "business/swap.zig",
    "cdp.zig": "business/cdp.zig",
    "audit.zig": "business/audit.zig",
    "compliance.zig": "business/compliance.zig",
    "risk.zig": "business/risk.zig",
    "portal.zig": "business/portal.zig",
    "constitution.zig": "business/constitution.zig",
    "core.zig": "core.zig"
}

def update_imports(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    dirname = os.path.dirname(file_path)
    rel_to_core = os.path.relpath(dirname, 'core')
    
    def replace_import(match):
        import_path = match.group(1)
        if import_path in mappings:
            target_path = mappings[import_path]
            # Calculate new relative path
            # target_path is relative to 'core'
            # rel_to_core is the current file's dir relative to 'core'
            if rel_to_core == '.':
                new_path = target_path
            else:
                # We are in a subdirectory of core, e.g., 'protocol'
                # To get to 'core', we need '../'
                new_path = os.path.join('..', target_path)
                # If target is in the same folder, we could keep it simple but ../folder/file.zig also works.
                # Actually, if we are in 'protocol' and target is 'protocol/types.zig',
                # new_path will be '../protocol/types.zig'. This works fine in Zig.
            
            # Special case for core.zig if we are in a subfolder
            if import_path == "core.zig" and rel_to_core != ".":
                new_path = "../core.zig"
                
            return f'@import("{new_path}")'
        return match.group(0)

    new_content = re.sub(r'@import\("([^"]+\.zig)"\)', replace_import, content)
    
    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

for root, dirs, files in os.walk('core'):
    for file in files:
        if file.endswith('.zig'):
            update_imports(os.path.join(root, file))
