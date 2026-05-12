#!/usr/bin/env bash
# scripts/cf_deploy.sh — one-shot Cloudflare Worker deploy for xB77.
#
# Deploys a SINGLE Worker that serves:
#   /             → webapp_deploy/index.html      (CF static assets, edge-cached)
#   /app.html     → webapp_deploy/app.html
#   /assets/*     → webapp_deploy/assets/*
#   /idls/*       → webapp_deploy/idls/*
#   /api/v1/*     → src/index.js fetch handler    (gateway logic)
#
# This is the modern Cloudflare pattern (May 2026) — Pages is in maintenance
# mode, Workers Static Assets serves the same role plus colocated API. One URL.
#
# Required env:
#   CLOUDFLARE_API_TOKEN   token with scopes:
#                            Workers Scripts:Edit
#                            Workers KV Storage:Edit
#                            Account Settings:Read
#                          (Pages scope NOT required anymore)
#   CLOUDFLARE_ACCOUNT_ID  your account ID (dash.cloudflare.com → right sidebar)
#
# Optional env:
#   ZNODE_RPC_URL          Solana RPC the Worker will hit
#                          default: https://api.devnet.solana.com
#   WORKERS_SUBDOMAIN      account-level subdomain to claim if none exists.
#                          default: xb77-<first 8 chars of account id>
#                          Ignored if a subdomain is already registered.
#   GATEWAY_PRIVKEY_HEX    pre-generated 64B hex (seed||pubkey).
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
SUMMARY_FILE="$REPO/.cf_deploy_summary"

ZNODE_RPC_URL="${ZNODE_RPC_URL:-https://api.devnet.solana.com}"

# ── Pre-flight ────────────────────────────────────────────────────────
say() { printf "\n\033[33;1m[cf-deploy]\033[0m %s\n" "$*"; }
die() { printf "\n\033[31;1m[cf-deploy] FAIL:\033[0m %s\n" "$*" >&2; exit 1; }

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]  || die "CLOUDFLARE_API_TOKEN is unset"
[[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || die "CLOUDFLARE_ACCOUNT_ID is unset"

# Wrangler v5 requires Node ≥ 22. If user is on older Node, prefer bun's
# runtime via `bunx wrangler@latest` (bun reports Node v22 compat, so wrangler
# passes its internal check). Otherwise use the globally installed wrangler.
WRANGLER="wrangler"
node_ok=0
if command -v node >/dev/null; then
  node_major="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
  [[ "$node_major" -ge 22 ]] 2>/dev/null && node_ok=1
fi

if [[ "$node_ok" -ne 1 ]] && command -v bun >/dev/null; then
  say "Node $(node -v 2>/dev/null || echo missing) too old for wrangler v5 — using bunx wrangler"
  WRANGLER="bunx --bun wrangler@latest"
elif ! command -v wrangler >/dev/null; then
  say "wrangler not found — installing via npm globally..."
  command -v npm >/dev/null || die "neither bun nor npm found; install one"
  npm install -g wrangler@latest >/dev/null 2>&1 || die "wrangler install failed"
fi

command -v node >/dev/null    || die "node not found (needed for keypair gen)"
command -v python3 >/dev/null || die "python3 not found (needed for toml patch)"

WRANGLER_VERSION="$($WRANGLER --version 2>/dev/null | head -1 || echo "?")"
say "wrangler $WRANGLER_VERSION  (via: $WRANGLER)"
say "Account: $CLOUDFLARE_ACCOUNT_ID"

# Make sure the webapp_deploy is built (or at least the JS files exist).
if [[ ! -f "$REPO/webapp_deploy/assets/js/app-tabs.js" ]]; then
  say "webapp_deploy/assets/js/ missing — running build.sh"
  (cd "$REPO/webapp_deploy" && bash build.sh)
fi

# ── Generate gateway Ed25519 keypair if not provided ──────────────────
# We capture node's stdout into a single variable and split with bash
# parameter expansion. The previous `read ... < <(node ...)` pattern was
# brittle because process.stdout.write() doesn't emit a trailing newline,
# which made `read` return non-zero, which with `set -e` killed the script
# silently right after the "Generating..." line.
if [[ -z "${GATEWAY_PRIVKEY_HEX:-}" ]]; then
  say "Generating fresh Ed25519 keypair for gateway signing..."
  KEYPAIR_OUT="$(node -e '
    const c = require("crypto");
    const k = c.generateKeyPairSync("ed25519");
    const priv = k.privateKey.export({ type: "pkcs8", format: "der" });
    const pub  = k.publicKey.export({ type: "spki", format: "der" });
    const seed = priv.slice(-32);
    const pubkey = pub.slice(-32);
    console.log(seed.toString("hex") + pubkey.toString("hex") + " " + pubkey.toString("hex"));
  ')"
  GATEWAY_PRIVKEY_HEX="${KEYPAIR_OUT% *}"
  GATEWAY_PUBKEY_HEX="${KEYPAIR_OUT##* }"
  [[ ${#GATEWAY_PRIVKEY_HEX} -eq 128 && ${#GATEWAY_PUBKEY_HEX} -eq 64 ]] \
    || die "keypair generation produced unexpected lengths (priv=${#GATEWAY_PRIVKEY_HEX}, pub=${#GATEWAY_PUBKEY_HEX}); node version may be too old. Need Node >= 12."
else
  GATEWAY_PUBKEY_HEX="${GATEWAY_PRIVKEY_HEX: -64}"
fi
say "Gateway pubkey (32B hex): $GATEWAY_PUBKEY_HEX"

# ── Generate INGEST_TOKEN if not provided ─────────────────────────────
if [[ -z "${INGEST_TOKEN:-}" ]]; then
  INGEST_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
fi
say "INGEST_TOKEN generated (length=${#INGEST_TOKEN})"

# ── Create / reuse 5 KV namespaces (via direct CF API — JSON, no text parsing) ──
# We were parsing `wrangler kv namespace create` text output, which differs
# between wrangler versions and breaks silently. Direct CF API returns JSON.
cd "$WORKER_DIR"
WORKER_NAME="$(python3 -c 'import re,pathlib; t=pathlib.Path("wrangler.toml").read_text(); m=re.search(r"^name\s*=\s*\"([^\"]+)\"", t, re.M); print(m.group(1) if m else "xb77-adapter")')"
say "Worker name: $WORKER_NAME"

cf_api() {
  # cf_api <METHOD> <PATH> [BODY_JSON]
  local method="$1" pth="$2" body="${3:-}"
  local args=(-sS -X "$method"
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
    -H "Content-Type: application/json")
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}" "https://api.cloudflare.com/client/v4$pth"
}

# ── Resolve / register workers.dev subdomain ──────────────────────────
# Three modes, in order:
#   1. WORKERS_SUBDOMAIN env var is set — TRUST it as already-registered,
#      skip the API roundtrip entirely. This is the path for users who
#      registered through the dashboard onboarding flow (where the API
#      token doesn't need the extra Account Settings:Edit permission that
#      programmatic registration requires).
#   2. WORKERS_SUBDOMAIN not set, GET succeeds → use what CF returns.
#   3. WORKERS_SUBDOMAIN not set, GET returns nothing → try PUT with a
#      default name. Requires Account Settings:Edit on the token.
if [[ -n "${WORKERS_SUBDOMAIN:-}" ]]; then
  sub_current="$WORKERS_SUBDOMAIN"
  say "Subdomain from env: $sub_current (trusted, skipping CF API roundtrip)"
else
  sub_get="$(cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/subdomain")"
  sub_current="$(printf '%s' "$sub_get" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if d.get('success'):
        r=d.get('result') or {}
        print(r.get('subdomain','') or r.get('name',''))
except Exception:
    pass
" 2>/dev/null || echo '')"

  if [[ -z "$sub_current" ]]; then
    SUBDOMAIN_DESIRED="xb77-${CLOUDFLARE_ACCOUNT_ID:0:8}"
    say "No subdomain detected — attempting to claim '$SUBDOMAIN_DESIRED' (needs Account Settings:Edit on token)..."
    sub_put="$(cf_api PUT "/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/subdomain" "{\"subdomain\":\"$SUBDOMAIN_DESIRED\"}")"
    sub_ok="$(printf '%s' "$sub_put" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("success"))' 2>/dev/null || echo False)"
    if [[ "$sub_ok" != "True" ]]; then
      printf '%s\n' "$sub_put" | head -10
      die "couldn't register workers.dev subdomain. Either it's taken globally (set WORKERS_SUBDOMAIN=<unique-name> and retry), the token lacks Account Settings:Edit (claim through dashboard onboarding and set WORKERS_SUBDOMAIN=<your-name>), or this is an authentication error (verify the token)."
    fi
    sub_current="$SUBDOMAIN_DESIRED"
    say "Subdomain claimed: $sub_current"
  else
    say "Subdomain already registered: $sub_current"
  fi
fi
EXPECTED_WORKER_URL="https://${WORKER_NAME}.${sub_current}.workers.dev"

# Fetch the existing KV namespace list once.
NS_LIST_JSON="$(cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/storage/kv/namespaces?per_page=100")"
ok="$(printf '%s' "$NS_LIST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("success"))')"
[[ "$ok" == "True" ]] || { printf '%s\n' "$NS_LIST_JSON" | head -20; die "CF API list KV failed — check token scopes"; }

declare -A KV_IDS
for ns in AGENTS ORDERS NONCES BUCKETS IDEMP; do
  title="${WORKER_NAME}-${ns}"
  # Reuse if title already exists
  id="$(printf '%s' "$NS_LIST_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('result',[])
for n in d:
    if n.get('title')=='$title':
        print(n['id']); break
")"
  if [[ -z "$id" ]]; then
    create_json="$(cf_api POST "/accounts/$CLOUDFLARE_ACCOUNT_ID/storage/kv/namespaces" "{\"title\":\"$title\"}")"
    id="$(printf '%s' "$create_json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if d.get('success'): print(d['result']['id'])
else: print('ERR:'+str(d.get('errors')))
")"
    if [[ "$id" == ERR:* || -z "$id" ]]; then
      printf '%s\n' "$create_json" | head -20
      die "CF API create KV '$title' failed: $id"
    fi
  fi
  KV_IDS[$ns]="$id"
  say "  KV $title → $id"
done

# ── Patch wrangler.toml: KV ids + ZNODE_RPC_URL ───────────────────────
say "Patching wrangler.toml with prod KV IDs + RPC..."
python3 - <<PY
import re, pathlib
p = pathlib.Path("wrangler.toml")
toml = p.read_text()
ids = {"AGENTS": "${KV_IDS[AGENTS]}", "ORDERS": "${KV_IDS[ORDERS]}", "NONCES": "${KV_IDS[NONCES]}", "BUCKETS": "${KV_IDS[BUCKETS]}", "IDEMP": "${KV_IDS[IDEMP]}"}

def replace_kv(name, real_id, text):
    pat = re.compile(r'(\[\[kv_namespaces\]\]\nbinding = "' + name + r'"\nid = ")[^"]+(")')
    return pat.sub(lambda m: m.group(1) + real_id + m.group(2), text, count=1)

for name, real_id in ids.items():
    toml = replace_kv(name, real_id, toml)

toml = re.sub(r'ZNODE_RPC_URL = "[^"]*"', f'ZNODE_RPC_URL = "${ZNODE_RPC_URL}"', toml)

p.write_text(toml)
print("  → wrangler.toml updated")
PY

# ── Set secrets (non-interactive) ─────────────────────────────────────
say "Setting GATEWAY_PRIVKEY_HEX secret..."
printf '%s' "$GATEWAY_PRIVKEY_HEX" | $WRANGLER secret put GATEWAY_PRIVKEY_HEX

say "Setting INGEST_TOKEN secret..."
printf '%s' "$INGEST_TOKEN" | $WRANGLER secret put INGEST_TOKEN

# ── Stage assets to a clean dir (skips walking remotion node_modules) ──
# wrangler walks the entire [assets].directory tree before applying
# .assetsignore filters. webapp_deploy/remotion/node_modules/ is ~670 MB /
# 16K files of build-tool dependencies that get filtered out anyway but
# eat 15-25s of walk time per deploy. Staging the production-only files
# into /tmp first means wrangler only walks ~90 files, ~2.5 MB.
STAGE_DIR="$(mktemp -d -t xb77-stage-XXXX)"
say "Staging static assets to $STAGE_DIR ..."
# rsync drops everything that .assetsignore would have excluded, plus
# anything we know wrangler doesn't need. Fast (~1s for ~2.5 MB).
rsync -a "$REPO/webapp_deploy/" "$STAGE_DIR/" \
  --exclude='remotion/' \
  --exclude='assets/src/' \
  --exclude='build.sh' \
  --exclude='*.map' \
  --exclude='.DS_Store' \
  --exclude='*.swp' \
  --exclude='*~' \
  > /dev/null
stage_size_kb="$(du -sk "$STAGE_DIR" | cut -f1)"
stage_count="$(find "$STAGE_DIR" -type f | wc -l)"
say "  → ${stage_count} files, ${stage_size_kb} KB"

# Temporarily repoint [assets].directory at the stage. Restore on EXIT
# (trap) so a crash mid-deploy doesn't leave wrangler.toml broken.
WRANGLER_TOML_BACKUP="$(mktemp)"
cp wrangler.toml "$WRANGLER_TOML_BACKUP"
trap "cp '$WRANGLER_TOML_BACKUP' '$WORKER_DIR/wrangler.toml' && rm -f '$WRANGLER_TOML_BACKUP' && rm -rf '$STAGE_DIR'" EXIT
sed -i "s|directory = \"../../webapp_deploy\"|directory = \"$STAGE_DIR\"|" wrangler.toml

# ── Deploy (Worker + Static Assets in one shot) ───────────────────────
say "Deploying Worker (with staged assets) — should be fast now ..."
# Stream output live AND capture to a tmpfile so we can parse the URL after.
DEPLOY_LOG="$(mktemp -t cf_deploy_XXXX.log)"
$WRANGLER deploy 2>&1 | tee "$DEPLOY_LOG"
deploy_exit="${PIPESTATUS[0]}"
[[ "$deploy_exit" -eq 0 ]] || die "wrangler deploy exited $deploy_exit — see output above"

WORKER_URL="$(grep -oE 'https://[a-z0-9.-]+\.workers\.dev' "$DEPLOY_LOG" | head -1 || echo '')"
# Fallback: if we couldn't parse it (output format changed), use the URL
# we know wrangler will use based on the registered subdomain + worker name.
[[ -z "$WORKER_URL" && -n "${EXPECTED_WORKER_URL:-}" ]] && WORKER_URL="$EXPECTED_WORKER_URL"
[[ -n "$WORKER_URL" ]] || die "couldn't determine Worker URL (log: $DEPLOY_LOG)"
say "Worker → $WORKER_URL"

# ── Health checks ─────────────────────────────────────────────────────
say "Health-checking $WORKER_URL/api/v1 ..."
curl -fsSL "$WORKER_URL/api/v1" | head -c 400 || die "Worker /api/v1 not responding"
echo ""
say "Health-checking $WORKER_URL/app.html (static asset) ..."
curl -fsSL -I "$WORKER_URL/app.html" | head -3 || die "static asset /app.html not served"

# ── Summary ───────────────────────────────────────────────────────────
cat > "$SUMMARY_FILE" <<EOF
{
  "worker_url":         "$WORKER_URL",
  "dapp_url":           "$WORKER_URL/app.html",
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

  Landing:  $WORKER_URL
  dApp:     $WORKER_URL/app.html
  API:      $WORKER_URL/api/v1
  RPC:      $ZNODE_RPC_URL

  Gateway pubkey (32B hex):  $GATEWAY_PUBKEY_HEX
  Ingest token (keep secret): $INGEST_TOKEN

  Summary saved to: $SUMMARY_FILE  (gitignored)

  Smoke test:
    curl -s "$WORKER_URL/api/v1" | jq
    curl -s "$WORKER_URL/api/v1/network/pulse" | jq
    open  "$WORKER_URL/app.html"

  Next step (capture devnet sections):
    export XB77_GATEWAY="$WORKER_URL"
    export INGEST_TOKEN="$INGEST_TOKEN"
    scripts/demo_capture.sh --rpc "$ZNODE_RPC_URL" --profile devnetdemo

================================================================
EOF
