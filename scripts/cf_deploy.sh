#!/usr/bin/env bash
# scripts/cf_deploy.sh — one-shot Cloudflare deploy for xB77.
#
# Deploys:
#   1. Worker  → https://xb77-adapter.<your-account>.workers.dev
#   2. Pages   → https://xb77-app.pages.dev  (or your project name)
#
# Required env:
#   CLOUDFLARE_API_TOKEN   token with scopes:
#                            Workers Scripts:Edit
#                            Workers KV Storage:Edit
#                            Cloudflare Pages:Edit
#                            Account Settings:Read
#   CLOUDFLARE_ACCOUNT_ID  your account ID (dash.cloudflare.com → right sidebar)
#
# Optional env:
#   ZNODE_RPC_URL          Solana RPC the Worker will hit
#                          default: https://api.devnet.solana.com
#   PAGES_PROJECT_NAME     default: xb77-app
#   GATEWAY_PRIVKEY_HEX    pre-generated 64-byte hex (seed||pubkey).
#                          If unset, this script generates a fresh keypair.
#   INGEST_TOKEN           pre-generated bearer for /pipelines/ingest.
#                          If unset, generated random.
#
# Usage:
#   export CLOUDFLARE_API_TOKEN=...
#   export CLOUDFLARE_ACCOUNT_ID=...
#   ./scripts/cf_deploy.sh
#
# Idempotent: safe to re-run. KV namespaces that already exist are reused.
# Secrets are overwritten on each run (cheap).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER_DIR="$REPO/gateway/worker"
PAGES_DIR="$REPO/webapp_deploy"
SUMMARY_FILE="$REPO/.cf_deploy_summary"

ZNODE_RPC_URL="${ZNODE_RPC_URL:-https://api.devnet.solana.com}"
PAGES_PROJECT_NAME="${PAGES_PROJECT_NAME:-xb77-app}"

# ── Pre-flight ────────────────────────────────────────────────────────
say() { printf "\n\033[33;1m[cf-deploy]\033[0m %s\n" "$*"; }
die() { printf "\n\033[31;1m[cf-deploy] FAIL:\033[0m %s\n" "$*" >&2; exit 1; }

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]  || die "CLOUDFLARE_API_TOKEN is unset"
[[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || die "CLOUDFLARE_ACCOUNT_ID is unset"

if ! command -v wrangler >/dev/null; then
  say "wrangler not found — installing via npm globally..."
  command -v npm >/dev/null || die "npm not found, install Node.js first"
  npm install -g wrangler >/dev/null 2>&1 || die "wrangler install failed"
fi

command -v node >/dev/null   || die "node not found (needed for keypair gen)"
command -v python3 >/dev/null || die "python3 not found (needed for toml patch)"

WRANGLER_VERSION="$(wrangler --version 2>/dev/null | head -1 || echo "?")"
say "wrangler $WRANGLER_VERSION"
say "Token has access to account $CLOUDFLARE_ACCOUNT_ID"

# ── Generate gateway Ed25519 keypair if not provided ──────────────────
if [[ -z "${GATEWAY_PRIVKEY_HEX:-}" ]]; then
  say "Generating fresh Ed25519 keypair for gateway signing..."
  read GATEWAY_PRIVKEY_HEX GATEWAY_PUBKEY_HEX < <(node -e '
    const c = require("crypto");
    const k = c.generateKeyPairSync("ed25519");
    const priv = k.privateKey.export({ type: "pkcs8", format: "der" });
    const pub  = k.publicKey.export({ type: "spki", format: "der" });
    const seed = priv.slice(-32);
    const pubkey = pub.slice(-32);
    process.stdout.write(seed.toString("hex") + pubkey.toString("hex") + " " + pubkey.toString("hex"));
  ')
else
  # Derive pubkey from the provided 64-byte hex (last 32 bytes)
  GATEWAY_PUBKEY_HEX="${GATEWAY_PRIVKEY_HEX: -64}"
fi
say "Gateway pubkey (32B hex): $GATEWAY_PUBKEY_HEX"

# ── Generate INGEST_TOKEN if not provided ─────────────────────────────
if [[ -z "${INGEST_TOKEN:-}" ]]; then
  INGEST_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
fi
say "INGEST_TOKEN generated (length=${#INGEST_TOKEN})"

# ── Create / reuse 5 KV namespaces ────────────────────────────────────
cd "$WORKER_DIR"
declare -A KV_IDS
for ns in AGENTS ORDERS NONCES BUCKETS IDEMP; do
  # Try create; if already exists, list and grep.
  out="$(wrangler kv namespace create "$ns" 2>&1 || true)"
  id="$(printf '%s\n' "$out" | grep -oE 'id = "[a-f0-9]+"' | head -1 | cut -d'"' -f2 || true)"
  if [[ -z "$id" ]]; then
    # Maybe already exists — query the list
    list="$(wrangler kv namespace list 2>/dev/null || echo '[]')"
    id="$(printf '%s' "$list" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for n in data:
    title = n.get('title','')
    # wrangler appends '-<binding>' to the worker name; ours is xb77-adapter-<NS>
    if title.endswith('-$ns') or title == '$ns':
        print(n['id'])
        break
" || true)"
  fi
  [[ -n "$id" ]] || die "could not resolve KV namespace id for $ns"
  KV_IDS[$ns]="$id"
  say "  KV $ns → $id"
done

# ── Patch wrangler.toml in place: KV ids + ZNODE_RPC_URL + ACCEPT_SCHEMA_1_0 ──
say "Patching wrangler.toml with prod KV IDs + RPC..."
python3 - <<PY
import re, pathlib
p = pathlib.Path("wrangler.toml")
toml = p.read_text()

ids = {"AGENTS": "${KV_IDS[AGENTS]}", "ORDERS": "${KV_IDS[ORDERS]}", "NONCES": "${KV_IDS[NONCES]}", "BUCKETS": "${KV_IDS[BUCKETS]}", "IDEMP": "${KV_IDS[IDEMP]}"}

def replace_kv_block(name, real_id, text):
    pat = re.compile(r'(\[\[kv_namespaces\]\]\nbinding = "' + name + r'"\nid = ")[^"]+(")')
    return pat.sub(lambda m: m.group(1) + real_id + m.group(2), text, count=1)

for name, real_id in ids.items():
    toml = replace_kv_block(name, real_id, toml)

# RPC override
toml = re.sub(r'ZNODE_RPC_URL = "[^"]*"', f'ZNODE_RPC_URL = "${ZNODE_RPC_URL}"', toml)

p.write_text(toml)
print("  → wrangler.toml updated")
PY

# ── Set secrets (non-interactive) ─────────────────────────────────────
say "Setting GATEWAY_PRIVKEY_HEX secret..."
printf '%s' "$GATEWAY_PRIVKEY_HEX" | wrangler secret put GATEWAY_PRIVKEY_HEX

say "Setting INGEST_TOKEN secret..."
printf '%s' "$INGEST_TOKEN" | wrangler secret put INGEST_TOKEN

# ── Deploy Worker ─────────────────────────────────────────────────────
say "Deploying Worker..."
deploy_out="$(wrangler deploy 2>&1)"
echo "$deploy_out" | tail -20
WORKER_URL="$(printf '%s' "$deploy_out" | grep -oE 'https://[a-z0-9.-]+\.workers\.dev' | head -1 || echo '')"
[[ -n "$WORKER_URL" ]] || die "couldn't parse Worker URL from deploy output"
say "Worker → $WORKER_URL"

# ── Health check the Worker ───────────────────────────────────────────
say "Health-checking $WORKER_URL/api/v1 ..."
curl -fsSL "$WORKER_URL/api/v1" | head -3 || die "Worker /api/v1 not responding"

# ── Deploy Pages ──────────────────────────────────────────────────────
cd "$PAGES_DIR"
say "Deploying Pages project '$PAGES_PROJECT_NAME'..."
# Create project if doesn't exist (idempotent)
wrangler pages project create "$PAGES_PROJECT_NAME" --production-branch=main 2>&1 \
  | grep -vE "already exists" || true

pages_out="$(wrangler pages deploy . --project-name "$PAGES_PROJECT_NAME" --branch main --commit-dirty=true 2>&1)"
echo "$pages_out" | tail -10
PAGES_URL="$(printf '%s' "$pages_out" | grep -oE 'https://[a-z0-9.-]+\.pages\.dev' | head -1 || echo '')"
[[ -n "$PAGES_URL" ]] || die "couldn't parse Pages URL"
say "Pages → $PAGES_URL"

# ── Summary ───────────────────────────────────────────────────────────
cat > "$SUMMARY_FILE" <<EOF
{
  "worker_url":         "$WORKER_URL",
  "pages_url":          "$PAGES_URL",
  "gateway_pubkey_hex": "$GATEWAY_PUBKEY_HEX",
  "ingest_token":       "$INGEST_TOKEN",
  "rpc_url":            "$ZNODE_RPC_URL",
  "kv_namespaces": {
    "AGENTS":  "${KV_IDS[AGENTS]}",
    "ORDERS":  "${KV_IDS[ORDERS]}",
    "NONCES":  "${KV_IDS[NONCES]}",
    "BUCKETS": "${KV_IDS[BUCKETS]}",
    "IDEMP":   "${KV_IDS[IDEMP]}"
  }
}
EOF

cat <<EOF

================================================================
xB77 DEPLOYED — ready for capture + render
================================================================

  Worker:  $WORKER_URL
  Pages:   $PAGES_URL

  Gateway pubkey (32B hex): $GATEWAY_PUBKEY_HEX
  Ingest token (keep secret): $INGEST_TOKEN

  Summary saved to: $SUMMARY_FILE  (gitignored)

  Test it:
    curl -s "$WORKER_URL/api/v1" | jq
    curl -s "$WORKER_URL/api/v1/network/pulse" | jq

  Next:
    export XB77_GATEWAY="$WORKER_URL"
    export INGEST_TOKEN="$INGEST_TOKEN"
    scripts/demo_capture.sh --rpc "$ZNODE_RPC_URL" --profile devnetdemo

================================================================
EOF
