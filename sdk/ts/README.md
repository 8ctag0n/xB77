# @xb77/sdk

TypeScript SDK for the **xB77 Sovereign Commerce Layer**. Powered by a single Zig-built `xb77_core.wasm` (75 KB, ReleaseSmall) — the same artifact that ships in the upcoming Rust crate, so every wrapper signs **byte-identical** requests.

```ts
import { XB77, Action } from "@xb77/sdk";

const sdk = await XB77.load();

// 1. Seal a private key with a password — produces a stateless blob
const sealed = sdk.keystore.seal(privKey, "correct horse battery staple");

// 2. Build a gateway-bound, Ed25519-signed request
const req = sdk.buildSignedRequest({
  gatewayBase: "https://gateway.xb77.dev",
  action: Action.SubmitOrder,
  payload: '{"symbol":"SOL/USDC","amount":1000000,"side":"buy"}',
  privkey: privKey, // 64 bytes (Ed25519 seed || pubkey, std.crypto canonical form)
});

// 3. The wrapper handles HTTP in your runtime — `fetch` here, `httpx` in Python, etc.
const res = await fetch(req.url, { method: req.method, headers: req.headers, body: req.body });

// 4. Verify the gateway's response signature against the pinned gateway pubkey
sdk.verifyResponse({
  body: new Uint8Array(await res.arrayBuffer()),
  expectedAction: Action.SubmitOrder,
  timestampUnix: Number(res.headers.get("X-Xb77-Gateway-Timestamp")),
  gatewayPubkey: GATEWAY_PUBKEY, // 32 bytes, pinned at install
  signature: fromHex(res.headers.get("X-Xb77-Gateway-Signature")!),
});
```

## Why this exists

The xB77 stack signs every gateway-bound request with the agent's Ed25519 key. Hand-rolling that signing in TypeScript means trusting `tweetnacl` or `@noble/ed25519`, doing JSON canonicalization, and praying nothing drifts from the gateway's expectations. This SDK replaces that with a single auditable WASM core: the bytes the wrapper signs are the bytes the gateway will verify, with zero room for serialization drift.

## Installation

```bash
npm i @xb77/sdk        # or: bun add @xb77/sdk
```

Requires Node ≥ 20 or Bun ≥ 1.1. Browsers and Cloudflare Workers also supported (the loader fetches `xb77_core.wasm` from same-origin by default).

## API

### `XB77.load(opts?: LoadOptions): Promise<XB77>`

Returns an SDK instance. The factory:

1. Locates `xb77_core.wasm` (bundled, fetched, or passed via `opts.wasmBytes`).
2. Instantiates the WASM with a minimal WASI shim (`random_get`, `fd_*`, `proc_exit`).
3. Verifies the ABI version is `1.x` — refuses to load a major-incompatible build.

### `sdk.keystore`

| Method | Signature | Notes |
|---|---|---|
| `seal(plain, password)` | `(Uint8Array, string) → Uint8Array` | PBKDF2-HMAC-SHA256 (4096 iters) + AES-256-GCM. Output is `plain.length + 44` bytes. Random salt+nonce each call. |
| `unseal(blob, password)` | `(Uint8Array, string) → Uint8Array` | Throws `Xb77Error` with `code === InvalidPassword` on wrong password. |
| `pubkey(privkey)` | `(Uint8Array) → Uint8Array` | Returns 32-byte Ed25519 public key from the 64-byte canonical secret (`seed||pubkey`). |

### `sdk.buildSignedRequest(args)`

```ts
type Args = {
  gatewayBase: string;        // "https://gateway.xb77.dev" (trailing slash OK)
  action: Action;             // SubmitOrder | RegisterAgent | ClaimCredits | QueryPulse
  payload: Uint8Array | string;
  privkey: Uint8Array;        // 64 bytes
  timestampUnix?: number;     // defaults to Date.now()/1000
};
type SignedRequest = {
  url: string;                // "${gatewayBase}/${action_path}"
  method: "POST";
  headers: Record<string, string>;
  body: Uint8Array;           // == payload, untouched
};
```

The canonical bytes signed are `action(1B) || timestamp_unix_be(8B) || payload`. See the [design addendum §A.1](../../docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.addendum.md#a1-canonical-bytes-for-signed-requests) for the locked spec.

### `sdk.verifyResponse(args)`

```ts
type Args = {
  body: Uint8Array;
  expectedAction: Action;
  timestampUnix: number;      // from "X-Xb77-Gateway-Timestamp" header
  gatewayPubkey: Uint8Array;  // 32 bytes, pinned at install
  signature: Uint8Array;      // 64 bytes, from "X-Xb77-Gateway-Signature"
};
```

Throws `Xb77Error` with `code === InvalidSignature` on tamper / mismatch.

## Errors

All wrapper functions throw `Xb77Error` on failure. The `code` field maps 1:1 to the [WASM ABI error codes (addendum §A.2)](../../docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.addendum.md#a2-abi-error-codes-locked-for-fase-2):

| `ErrorCode` | When |
|---|---|
| `InvalidInput` | Wrong-length privkey / pubkey / signature, malformed args |
| `BufferTooSmall` | Internal — wrapper auto-handles via the probe-then-alloc pattern |
| `InvalidPassword` | `keystore.unseal` AES-GCM tag mismatch |
| `InvalidSignature` | `verifyResponse` Ed25519 verify failed |
| `InvalidAction` | Action byte outside `0x01..0x04` |
| `OutOfMemory` | WASM allocator returned NULL |
| `InvalidBlob` | Sealed blob shorter than `SEAL_OVERHEAD` or corrupt |

## Cross-language conformance

The SDK is exactly **one** Zig codebase, compiled once to `xb77_core.wasm`. The TypeScript, Rust (and upcoming Python/Go) wrappers are thin transport adapters — they don't reimplement crypto. So a request built by the TS wrapper is **byte-identical** to one built by the Rust wrapper, given the same inputs and the same WASM artifact.

This is enforced by the test suite (`sdk/tests/cross_conformance.zig` — running in v1.0):
- Fixed Ed25519 seed → identical signature across all wrappers.
- Verified independently against WebCrypto's Ed25519 verifier in `sdk/ts/test/conformance.test.ts`.

## Acknowledged debt (v1.0)

Read the [addendum §A.6](../../docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.addendum.md#a6-acknowledged-debt-post-v1) for the full list. Highlights:

- **Replay protection** is gateway-enforced (timestamp window), not nonce-based. Real fix in v1.1.
- **Action enum locked to 4 values** in v1.0. Adding new actions = minor ABI bump.
- **Gateway pubkey distribution** is via compile-time pinning. Multi-gateway support post-v1.
- **No request ID** — operators correlate via `(pubkey, timestamp, action)`.

## Development

```bash
# Build the WASM artifact (from repo root)
zig build sdk-wasm

# In sdk/ts:
bun install
bun test           # 22 tests / 45 assertions / ~300ms
bun run build      # emits dist/index.{js,d.ts}
```

The test suite spins up an in-process mock gateway via `bun.serve` and exercises the full HTTP round-trip with WebCrypto Ed25519 acting as the independent verifier. See `test/e2e-gateway.test.ts`.

## License

MIT.
