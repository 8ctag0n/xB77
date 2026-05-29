# Sponsor submission forms — paste-ready drafts

Each file in this folder is a complete form-fill draft for one sponsor track. Fields are in the order the Frontier hackathon form presents them. The placeholders (`<...>`) are the only things you need to fill before submitting.

## Status

| Sponsor | File | Form submitted? | Demo video uploaded? |
|---|---|---|---|
| MagicBlock | [magicblock.md](magicblock.md) | yes (backup video) | needs swap for demo_magicblock.mp4 |
| Bonfida / SNS | [bonfida.md](bonfida.md) | pending | needs demo_bonfida.mp4 |
| Cloudflare Workers | [cloudflare.md](cloudflare.md) | pending | can use demo_v3.mp4 today |
| Solana base | [solana.md](solana.md) | pending | needs demo_solana.mp4 |
| QVAC / Tinfoil | [qvac.md](qvac.md) | pending | needs demo_qvac.mp4 |
| 100xDevs (side track) | [100xdevs.md](100xdevs.md) | pending — needs BOTH Colosseum + Superteam Earn | any cut works (demo_v3.mp4 generic) |

## Per-submission checklist

Before pasting a form:

- [ ] Demo video uploaded to YouTube (Unlisted) and link copied
- [ ] GitHub repo pushed and public (force-with-lease the rewritten history first)
- [ ] X profile link ready (or leave blank if no presence)
- [ ] CF deploy summary handy (in case forms ask for KV IDs or worker URL)

Then walk through the file top-to-bottom — every field has a code block ready to copy.

## Common values across all forms

```
Github:     https://github.com/8ctag0n/xB77v2
Deployment: https://xb77-adapter.frontier247hack.workers.dev
dApp:       https://xb77-adapter.frontier247hack.workers.dev/app
API:        https://xb77-adapter.frontier247hack.workers.dev/api/v1
```

Gateway pubkey (Ed25519, last 32B of seed||pubkey):
```
46877b09dd8fd5e7afc068c6722a5ba9a3301a4f4dbab01742c52f01f0f1aa44
```

Five deployed programs (devnet):

| Program | ID |
|---|---|
| xb77_core | `73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3` |
| xb77_gateway | `83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4` |
| xb77_registry | `HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1` |
| xb77_compression | `6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN` |
| xb77_zk_verifier | `J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ` |
