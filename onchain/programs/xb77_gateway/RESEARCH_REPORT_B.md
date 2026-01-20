# Research Report: Light Protocol and Local Validator Infrastructure

Date: Jan 20, 2026
Context: Worktree B (Vault Light / Gateway)
Goal: Establish a stable local environment for End-to-End testing of ZK Compression.

## Blockers

### 1. Official CLI (light test-validator)
* Issue: The tool attempts to download binary artifacts from GitHub Release URLs that return 404 Not Found.
* Specific Failures: light_system_program_pinocchio.so, light_compressed_token.so.
* Conclusion: Cannot rely on the automated setup of the @lightprotocol/zk-compression-cli.

### 2. Surfpool (Docker)
* Issue: The surfpool/surfpool image starts successfully but does not preload Light Protocol programs by default.
* Runbooks: Configuration via Surfpool.toml or .tx files requires specific syntax (Txtx) that is not clearly documented for this use case.
* Devnet Forking: Starting with --network devnet fails to reliably serve the program accounts locally in the containerized environment.

## Solution: Manual Binary Loading

The necessary Light Protocol programs have been compiled from source. The reliable path forward is to use the standard Solana Validator and load these binaries explicitly via the --bpf-program flag.

### 1. Compiled Binaries (Artifacts)
Binaries are extracted to: containers/surfpool/bin/
1. light_system_program_pinocchio.so
2. light_compressed_token.so
3. account_compression.so

### 2. Critical Program IDs
The following addresses must be used when loading the programs:

| Program | ID (Mainnet/Devnet) |
| :--- | :--- |
| Light System Program | SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7 |
| Compressed Token | cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m |
| Account Compression | compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq |
| Noop Program | noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV |

### 3. Execution Command
Instead of light test-validator or surfpool, use:

```bash
solana-test-validator \
  --bpf-program SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7 containers/surfpool/bin/light_system_program_pinocchio.so \
  --bpf-program cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m containers/surfpool/bin/light_compressed_token.so \
  --bpf-program compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq containers/surfpool/bin/account_compression.so \
  --reset
```

## Next Steps
1. Create scripts/localnet/start-validator-light.sh to automate this setup.
2. Validate the local RPC responses before deploying the Gateway program.
