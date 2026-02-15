# Light Stack Dump

Canonical local bundle location:
- `containers/light/bin`

## RPC URLs
| Network | Service | URL |
|---|---|---|
| Mainnet | Network Address (RPC) | `https://mainnet.helius-rpc.com?api-key=<api_key>` |
| Mainnet | Photon RPC API | `https://mainnet.helius-rpc.com?api-key=<api_key>` |
| Local | Solana RPC | `http://127.0.0.1:8899` |
| Local | Compression RPC | `http://127.0.0.1:8784` |
| Local | Prover RPC | `http://127.0.0.1:3001` |

## Program IDs
| Program | Public Key |
|---|---|
| Light System Program | `SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7` |
| Light Token Program | `cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m` |
| Account Compression Program | `compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq` |

## V2 State Trees / Output Queues / CPI Contexts
| Slot | State Tree | Output Queue | CPI Context |
|---|---|---|---|
| #1 | `bmt1LryLZUMmF7ZtqESaw7wifBXLfXHQYoE4GAmrahU` | `oq1na8gojfdUhsfCpyjNt6h4JaDWtHf1yQj4koBWfto` | `cpi15BoVPKgEPw5o8wc2T816GE7b378nMXnhH3Xbq4y` |
| #2 | `bmt2UxoBxB9xWev4BkLvkGdapsz6sZGkzViPNph7VFi` | `oq2UkeMsJLfXt2QHzim242SUi3nvjJs8Pn7Eac9H9vg` | `cpi2yGapXUR3As5SjnHBAVvmApNiLsbeZpF3euWnW6B` |
| #3 | `bmt3ccLd4bqSVZVeCJnH1F6C8jNygAhaDfxDwePyyGb` | `oq3AxjekBWgo64gpauB6QtuZNesuv19xrhaC1ZM1THQ` | `cpi3mbwMpSX8FAGMZVP85AwxqCaQMfEk9Em1v8QK9Rf` |
| #4 | `bmt4d3p1a4YQgk9PeZv5s4DBUmbF5NxqYpk9HGjQsd8` | `oq4ypwvVGzCUMoiKKHWh4S1SgZJ9vCvKpcz6RT6A8dq` | `cpi4yyPDc4bCgHAnsenunGA8Y77j3XEDyjgfyCKgcoc` |
| #5 | `bmt5yU97jC88YXTuSukYHa8Z5Bi2ZDUtmzfkDTA2mG2` | `oq5oh5ZR3yGomuQgFduNDzjtGvVWfDRGLuDVjv9a96P` | `cpi5ZTjdgYpZ1Xr7B1cMLLUE81oTtJbNNAyKary2nV6` |

## Address Trees
| Type | Public Key |
|---|---|
| V2 Address Tree | `amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx` |

## Interface PDA
| Item | Public Key |
|---|---|
| Interface PDA | `GXtd2izAiMJPwMEjfgTRH3d7k9mjn4Jq3JrWFv9gySYy` |

## Lookup Tables
| Item | Public Key |
|---|---|
| Lookup Table #1 (Mainnet) | `9NYFyEqPkyXUhkerbGHXUXkvb4qpzeEdHuGpgbgpH1NJ` |
| Lookup Table #1 (Devnet) | `qAJZMgnQJ8G6vA3WRcjD9Jan1wtKkaCFWLWskxJrR5V` |

## System Accounts List (CPI)
| Index | Account | Purpose |
|---|---|---|
| 1 | Light System Program | Validity proof and ownership checks |
| 2 | CPI Signer | PDA signer derived from caller program ID |
| 3 | Registered Program PDA | Access control to account compression |
| 4 | Account Compression Authority | CPI authority to compression program |
| 5 | Account Compression Program | Writes state and address trees |
| 6 | System Program | Lamport transfer operations |

## Required Local Binaries
- `light_system_program_pinocchio.so`
- `light_compressed_token.so`
- `account_compression.so`

## Operational Files
- `containers/light/bin/light-localnet.env`
- `scripts/localnet/start-validator-light.sh`
