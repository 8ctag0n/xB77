# Bonfida / SNS — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link to `demo_bonfida.mp4`
- `<X_HANDLE>` — your X profile URL (e.g. `https://x.com/dzkinha`)

---

## Link to Your Submission

```
https://xb77-adapter.frontier247hack.workers.dev
```

## Tweet Link

```
<deja vacío si no hay tweet del proyecto>
```

## Project Title

```
xB77 — Native .sol Resolution in Pure Zig
```

## Project Description

```
xB77 is sovereign agent commerce infrastructure for Solana, with the identity layer built around SNS resolved natively in Zig — no SDK roundtrip, no Bonfida API dependency, byte-for-byte parity with mainnet.

The SNS work lives in core/security/identity.zig. The resolveSnsNative function:
  1. Derives the SNS registry PDA from the domain hash + SOL_TLD_REGISTRY constants (using Crypto module's PDA primitive in Zig)
  2. Fetches the account via Solana RPC
  3. Decodes the registry record and extracts the owner pubkey
  4. Returns the resolved pubkey — zero external API calls

Validation: `zig build sns-test` calls the Bonfida public API for bonfida.sol AND runs our native derivation against the same RPC, then asserts the two pubkeys match. Output:
  [SNS TEST] API Result:    Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v
  [SNS TEST] Native Result: Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v
  [SNS TEST]  MATCH! Native engine is 100% Sovereign.

The CLI exposes identity resolve as `xb77 -p <profile> identity resolve <name>.sol` and the agent's status dashboard (xb77 status) shows the resolved domain with a "Native Verified" badge when the local PDA matches the on-chain account.

Pending (honest delta): the dApp's ConnectionPill currently shows the agent's keypair hash ag_xxx… and doesn't yet fire xb77:domain-resolved to swap it for <name>.sol. The hook is spec'd in docs/specs/sponsors/sns.md; landing it next iteration.

The 17 SNS exploration scripts that lived in /scripts during PDA reverse-engineering have been pruned — the canonical, tested path is in core/security/identity.zig.
```

## Project Github Link

```
https://github.com/8ctag0n/xB77v2
```

## Deployment Link

```
https://xb77-adapter.frontier247hack.workers.dev
```

## Demo Link

```
<YOUTUBE_URL>
```

## Project X Profile Link

```
<X_HANDLE>
```

## Your Program Pubkey (if program available)

```
HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1
```

(xb77_registry — where merchants register with SNS-resolvable identities)

## Anything Else?

```
Native PDA derivation in Zig: core/security/identity.zig:resolveSnsNative
Test harness:                  tests/sns_test.zig (run via zig build sns-test)
Spec:                          docs/specs/sponsors/sns.md
Submission writeup:            docs/submissions/SNS.md

Built end-to-end by one operator. The native resolver is novel because every other SNS integration in the ecosystem (that I know of) either uses Bonfida's HTTP API or @solana/spl-name-service in JS — making them dependent on a third party. Our Zig path resolves directly from the on-chain registry account.
```
