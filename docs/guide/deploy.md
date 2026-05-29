# xB77 — Deploy Guide

Complete walkthrough for taking a fresh Release and getting every
component live: Solana programs on devnet/mainnet, the gateway on
Cloudflare Workers, and the sovereign agent on Fly.io.

The toolbox containers (`infra/Containerfile.flyctl` + `Containerfile.wrangler`)
keep the deploy environment reproducible — no Node, no flyctl, no
Solana CLI on the host. Mount the repo + your credential dirs and go.

---

## 0. Prerequisites

| Account | Needed for | Cost |
|---|---|---|
| GitHub | host the repo + Releases | free |
| Cloudflare | Workers + Pages | free tier covers gateway + landing |
| Fly.io | znode + agent VM | free tier ≈ 3 micro-VMs |
| Solana wallet | program deploy | airdrop free on devnet |

You also need a Yellowstone-style Solana RPC endpoint (Quicknode, Helius,
Triton — most have free tiers).

---

## 1. Build the toolboxes

Run once from the repo root:

```bash
podman build -t xb77-toolbox  -f infra/Containerfile.flyctl   .
podman build -t xb77-wrangler -f infra/Containerfile.wrangler .
```

Verify they work:

```bash
podman run --rm xb77-toolbox  fly version
podman run --rm xb77-toolbox  solana --version
podman run --rm xb77-wrangler wrangler --version
```

---

## 2. Generate (or recover) the deploy wallet

The wallet that pays for `solana program deploy` (and acts as upgrade
authority) is a single 64-byte keypair JSON. **You hold the private key —
nobody else, including this guide.** Store it in `~/.config/solana/`
on the host so the toolbox container picks it up via volume mount.

### Fresh wallet

```bash
mkdir -p ~/.config/solana
podman run --rm -it \
    -v "$HOME/.config/solana:/root/.config/solana" \
    xb77-toolbox \
    solana-keygen new \
        --outfile /root/.config/solana/id.json \
        --no-bip39-passphrase
```

The pubkey it prints is your wallet address. After this, the file
`~/.config/solana/id.json` exists on your host and is the only artifact
that proves ownership. **Back it up offline before doing anything else.**

### Verify

```bash
podman run --rm \
    -v "$HOME/.config/solana:/root/.config/solana" \
    xb77-toolbox \
    solana address
```

Should print the same pubkey.

---

## 3. Deploy Solana programs to devnet

### 3.1 Configure the toolbox to point at devnet

```bash
podman run --rm -it \
    -v "$PWD:/work" \
    -v "$HOME/.config/solana:/root/.config/solana" \
    xb77-toolbox bash

# inside the container
solana config set \
    --url https://api.devnet.solana.com \
    --keypair /root/.config/solana/id.json
solana config get
```

### 3.2 Airdrop SOL

Devnet airdrops are rate-limited (max 2 SOL per request, ~5–10 SOL/day
per IP). Each program deploy costs ~3–5 SOL in account rent. Budget
~25 SOL for the five xB77 programs on first deploy (subsequent upgrades
are cheaper since the buffer can be reused).

```bash
solana airdrop 2
solana airdrop 2
solana airdrop 2
# wait a few minutes between requests if rate-limited
solana balance
```

If the airdrop faucet is exhausted, use the web faucet at
https://faucet.solana.com/ which sometimes has more headroom.

### 3.3 Build and deploy each program

The program IDs are pinned in `onchain/programs/<name>/src/lib.rs`
via `declare_id!(...)`. Their corresponding keypair files in
`onchain/programs/<name>/target/deploy/<name>-keypair.json` are what
make the deployed `.so` bind to those IDs. Treat those keypair files
as sensitive — they're pinned to the program address forever.

```bash
# From inside the toolbox container, /work is the repo root.
for prog in xb77_core xb77_gateway xb77_registry xb77_compression xb77_zk_verifier; do
  cd /work/onchain/programs/$prog
  cargo build-sbf
  solana program deploy \
      target/deploy/${prog}.so \
      --program-id target/deploy/${prog}-keypair.json
done
```

Confirm:

```bash
solana program show 73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3   # xb77_core
solana program show 4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC   # xb77_gateway
solana program show 6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN   # xb77_compression
solana program show J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ   # xb77_zk_verifier
# (look up xb77_registry pubkey in onchain/programs/xb77_registry/src/lib.rs)
```

Each `solana program show` prints program data length + upgrade authority.
The upgrade authority should be your deploy wallet pubkey.

---

## 4. Deploy the gateway to Cloudflare Workers

Two paths — choose one.

### 4a. CI (recommended)

Already wired in `.github/workflows/deploy-worker.yml`. Required
repository secrets:

* `CLOUDFLARE_API_TOKEN` — token with permissions
  *Workers Scripts:Edit*, *Workers Tail:Read*, *Account:Read*.
  Create at https://dash.cloudflare.com/profile/api-tokens.
* `CLOUDFLARE_ACCOUNT_ID` — numeric, visible in any zone URL or in
  the dashboard sidebar.

The workflow fires on every published Release, downloads the matching
`gateway.wasm` from that Release, and runs `wrangler deploy`. Re-run
manually via Actions → Deploy Worker → Run workflow → tag.

### 4b. Manual via toolbox

```bash
podman run --rm -it \
    -v "$PWD:/work" \
    -e CLOUDFLARE_API_TOKEN=...    \
    -e CLOUDFLARE_ACCOUNT_ID=...   \
    xb77-wrangler bash

# inside
zig build wasm -Doptimize=ReleaseSmall   # or download from Release
cp zig-out/bin/gateway.wasm gateway/gateway.wasm
wrangler deploy
```

After the first successful deploy the worker is live at
`https://xb77-gateway.<your-subdomain>.workers.dev`. Custom domain
goes into `wrangler.toml` under `[[routes]]`.

---

## 5. Deploy the sovereign agent to Fly.io

```bash
podman run --rm -it \
    -v "$PWD:/work" \
    -v "$HOME/.fly:/root/.fly" \
    xb77-toolbox bash

# inside
fly auth login                                     # opens browser flow
fly apps create xb77-agent                         # idempotent
fly secrets set YELLOWSTONE_ENDPOINT=https://...   # required
fly secrets set YELLOWSTONE_TOKEN=...              # only if your provider needs it
fly deploy                                         # builds with infra/Containerfile.agent and ships
fly logs                                           # tail the running VM
```

The agent listens on port 8081 internally and Fly fronts it with
HTTPS at `https://xb77-agent.fly.dev`. Auto-stop kicks in after idle,
so the free tier covers a hobbyist workload.

---

## 6. Deploy the landing page (Pages)

Two options:

* **Cloudflare Pages** — connect the GitHub repo, point at the `docs/`
  directory, set build command to "(none, static)". Free, custom domain
  free, faster CDN than GH Pages.
* **GitHub Pages** — already wired in `.github/workflows/deploy-docs.yml`.
  Requires the repo to be public (Pages on private repos is paid). Fires
  on push to `main` whenever `docs/**` changes, or via workflow_dispatch.

---

## 7. Verify everything end to end

```bash
# Gateway is alive
curl -fsSL https://xb77-gateway.<subdomain>.workers.dev/health

# Programs respond on devnet
solana program show 73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3

# Agent is alive
curl -fsSL https://xb77-agent.fly.dev/health
fly logs

# zk pipeline (e2e from Release)
gh release download v0.2.2-deluxe --pattern 'zk-upload-e2e'
chmod +x zk-upload-e2e
./zk-upload-e2e --rpc https://api.devnet.solana.com
```

---

## 8. Rollback

* **Worker** — `wrangler rollback` (or re-run the workflow against the
  previous tag).
* **Fly app** — `fly releases` then `fly deploy --image <previous-image-ref>`.
* **Solana program** — `solana program deploy --program-id <kp>` against
  the previous `.so` bytes; the on-chain ID is fixed, only the buffer
  changes. Keep prior `.so` artifacts from past Releases for this.

---

## Operational hygiene

* The deploy wallet keypair (`~/.config/solana/id.json`) is the **only**
  thing that lets you upgrade the programs. Back it up to two offline
  locations.
* Each program keypair (`onchain/programs/*/target/deploy/*-keypair.json`)
  is the **program ID** — losing it means you can no longer deploy
  upgrades to that ID. Treat them as version-controlled but never publish
  the bytes elsewhere.
* CF API token, Fly token, RPC tokens — rotate quarterly, store in a
  password manager, never echo into logs.
