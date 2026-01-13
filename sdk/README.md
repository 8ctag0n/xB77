# sdk

To install dependencies:

```bash
bun install
```

To run:

```bash
bun run index.ts
```

To validate the Noir proof pipeline (Node.js):

```bash
node test_badge.mjs
```

To generate Groth16 proofs and instruction data for on-chain verification:

```bash
# Uses the Noir + Sunspot container runtime.
bun run scripts/generate_badge_proof.ts
# or
bun run proof:badge
```

Outputs:
- `sdk/target/agent_badge.instruction.bin` (binary `proof || public_witness`)
- `sdk/target/agent_badge.instruction.b64` (base64 for transport)

To (re)generate the Noir artifact used by the scripts (via container):

```bash
./scripts/build-noir-artifacts.sh
```

Proof inputs live in `sdk/fixtures/agent_badge_inputs.json`.

First run downloads the CRS into `sdk/.bb-crs` and requires network access.

This project was created using `bun init` in bun v1.3.3. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
