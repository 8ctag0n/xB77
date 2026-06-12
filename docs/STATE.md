# xB77 — Estado real del stack (Open House sprint)

> Última actualización: 2026-06-11 | Rama: devstylus | Commit base: afc5663

---

## TL;DR honesto

| Capa | Estado |
|------|--------|
| **WASM on-chain** (Stylus contracts) | Completos, validados, no desplegados |
| **Bridge AWP → chain** (settle, anchor, zk_verify) | ✅ Los 3 conectados on-chain |
| **Firma de transacciones** | ✅ EIP-155 RLP signing — validado contra Anvil |
| **Generación de pruebas ZK** | Mockeada (`XB77_MOCK_PROVER=1`) |
| **Deploy en Sepolia** | Bloqueado — esperando ETH en `0x64a33...b02` |

---

## Tabla completa de stubs

| # | Stub | Archivo:línea | Qué falsifica | ¿Existe implementación real? | Costo para producción |
|---|------|---------------|---------------|------------------------------|-----------------------|
| 1 | ~~`verifyZkProof()` en bridge~~ | ~~`core/mesh/znode_bridge.zig:57-61`~~ | ~~`proof.len >= 64 → true`~~ | ✅ CERRADO — llama `ArbitrumAdapter.verifyZKProof()` → `callViewStr` on-chain | — |
| 2 | Prueba ZK individual (`XB77_MOCK_PROVER=1`) | `core/kernel/prover.zig:40-46` | Imprime "MOCK_MODE: verified" sin ejecutar nargo | ✅ `circuits/zk_receipt/` (7 circuitos Noir), `scripts/nargo.sh` | Instalar nargo + quitar guard |
| 3 | Batch anchor en prover | `core/kernel/prover.zig:139-143` | Imprime `mock_batch_anchor_sig_777...` | ✅ `ArbitrumAdapter.anchorStateRoot()` ya funciona (bridge lo llama), `onchain/stylus/anchor.zig` completo | Llamar `ArbitrumAdapter.anchorStateRoot()` desde prover |
| 4 | ~~`sendTx` sin firma~~ | ~~`core/chain/evm.zig:111-130`~~ | ~~`eth_sendTransaction` Anvil~~  | ✅ CERRADO — `sendSignedTx()` EIP-155 completo; `ArbitrumAdapter.txSend()` despacha según key | — |
| 5 | `canOperate()` bypass | `XB77_DEMO=1` → `core/kernel/orchestrator.zig:129` | Retorna `true` sin verificar balance | ✅ `syncBalance()` hace llamada HTTP real al Gateway; billing logic existe | Configurar Gateway URL + fondear wallet ops |
| 6 | `constitution.similarity` | `core/chain/arbitrum_adapter.zig:113` | `.similarity = 0` siempre | Parcial — `check_constitution()` hace RPC real, `approved` correcto; solo similarity no parseado | Parsear segundo word del ABI return |
| 7 | Stylus en Sepolia | — | Stubs Solidity en Anvil (`/tmp/xb77_stubs/`) | ✅ Los 3 contratos pasan `cargo stylus check --no-verify` | Fondear `0x64a33...b02` con ~0.02 Sepolia ETH; `deploy.sh deploy` |
| 8 | Nonces / gas en EVM client | `core/chain/evm.zig` (sendTx no pasa gas) | Anvil maneja gas automáticamente | Parcial — se puede agregar `gas` field al JSON RPC | Agregar gasLimit al buildTx |

---

## Estado por opcode AWP

| Opcode | Hex | Bridge → local | Bridge → on-chain | Test automatizado |
|--------|-----|----------------|--------------------|-------------------|
| `zk_verify` | `0x1C` | ✅ decodifica, responde | ✅ llama `verifyZKProof()` on-chain | ❌ |
| `anchor_root` | `0x1D` | ✅ guarda en store | ✅ llama `anchorStateRoot()` | `tests/znode_e2e.zig` ✅ |
| `settle` | `0x1E` | ✅ decodifica | ✅ llama `settlePayment()` | `tests/znode_e2e.zig` ✅ |
| `handshake` | `0x01` | ✅ responde ACK | — | — |
| todos los demás | varios | ✅ decode-and-discard | — | — |

---

## Estado de los contratos WASM (Stylus)

| Contrato | Archivo | Líneas | `cargo stylus check` | Desplegado |
|----------|---------|--------|----------------------|------------|
| `zk_verifier` | `onchain/stylus/zk_verifier.zig` | ~580 | ✅ PASS | ❌ |
| `settlement_engine` | `onchain/stylus/settlement_engine.zig` | ~420 | ✅ PASS | ❌ |
| `anchor` | `onchain/stylus/anchor.zig` | ~260 | ✅ PASS | ❌ |
| `groth16_verifier` | `onchain/stylus/groth16_verifier.zig` | 158 | ✅ PASS | ❌ |

### Calidad real del WASM

**`zk_verifier.zig`** — NO es un stub. Es una implementación completa:
- UltraPlonk: header parsing, G1 identity check, Fiat-Shamir transcript (Keccak256), KZG batched check vía `ecPairing` (precompile 0x08)
- Groth16: dispatcher `proof[0] == 0x01`, `e(-A,B) * e(α,β) * e(vk_x,γ) * e(C,δ) == 1` con 4-pair ecPairing
- VK hardcodeado para `agent_badge` circuit (G16_ALPHA_G1, IC[4])
- SRS Aztec Ignition en G2 (`AZTEC_G2_TAU`)
- Gap documentado: "Full UltraPlonk post-hackathon requiere segundo punto [τ]G2"

**`groth16_verifier.zig`** — Completo, 158 líneas, Miller loop puro WASM en `bn254/groth16.zig` (213 líneas). Gas: ~42M (excede ink cap de Stylus). Workaround: usar `ecPairing` precompile para el pairing final → ~215k gas.

**`settlement_engine.zig`** — Completo: `settle(address,uint256,bytes32)`, `batchSettle`, `handleReceiveMessage` (Circle CCTP), `getBalance`, lógica USDC.

**`anchor.zig`** — Completo: `anchorRoot(bytes32)`, `verifyAndAnchor`, `getRoot()`, `getBatchCount()`.

---

## Tests automatizados: cobertura honesta

```
✅ PASAN (automatizados)              ❌ NO TIENEN TESTS
──────────────────────────────        ────────────────────────────────────────
BN254 aritmética (63/63)             Prover.zig (cero tests)
Groth16 verifier (63/63)             Orchestrator real execution
Contract mock_hooks (59/59)          Mesh / P2P
Stylus check / estimate-gas (9/9)    CLI contra RPC en vivo
Crypto / keystore / compresión       Node + agent + memory persistence e2e
Anvil E2E (4/4 — anchor/settle/zk)  
znode_e2e (5/5 opcodes)             
```

---

## Próxima sesión — checklist de cierre para Open House

### Desbloqueante externo (no es código)
```bash
# Fondear wallet ops con Sepolia ETH desde cualquier faucet:
# - cloud.google.com/application/web3/faucet/ethereum/sepolia  (no requiere nada)
# - sepoliafaucet.com  (requiere cuenta Alchemy)
# Wallet: 0x8d82FB4f03857c3040d42450CAE2E0dCe9f94F1c
# Mínimo: 0.02 ETH — recomendado: 0.05 ETH para 2-3 intentos de deploy

# Verificar que llegó:
cast balance 0x8d82FB4f03857c3040d42450CAE2E0dCe9f94F1c \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc
```

### Paso 1 — Deploy a Arbitrum Sepolia (~1h)
```bash
cd onchain/stylus
./deploy.sh deploy
# Guarda las 3 direcciones que imprime en .env.sepolia
```

### Paso 2 — Stub #3: prover anchor firmado (~30 min)
`core/kernel/prover.zig:139-143` imprime `mock_batch_anchor_sig_777...`.
Reemplazar con llamada real a `ArbitrumAdapter.anchorStateRoot()` usando
el `eth_kp` del vault — mismo patrón que los bridge handlers.

### Paso 3 — E2E contra Sepolia (~30 min)
```bash
source .env.sepolia
XB77_ARB_RPC=https://sepolia-rollup.arbitrum.io/rpc \
XB77_DEMO=1 XB77_MOCK_PROVER=1 \
./zig-out/bin/xb77 serve
# Terminal 2: SDK burst — settle + anchor_root + zk_verify
# Verificar tx hashes en Arbiscan
```

### Paso 4 — Status bar del nodo (~2h)
Implementar `core/kernel/statusbar.zig` con stats atómicos (settle/anchor/zk counts,
last tx hash, uptime, RPC, modo). Se imprime cada 3s desde el engine loop.
Hace el demo video significativamente más impresionante.

### Paso 5 — Demo video + submission (~2h)
- Grabar: `serve` arranca → SDK envía burst → status bar muestra counters incrementar
  → Arbiscan muestra 3 tx hashes reales
- Submission: contract addresses, tx hashes, repo link, 3-min video

---

## Variables de entorno requeridas

| Var | Valor dev | Valor prod | Efecto |
|-----|-----------|------------|--------|
| `XB77_PASSWORD` | `dev` | vault password | Desencripta keystore |
| `XB77_DEMO` | `1` | quitar | Bypasses `canOperate()` |
| `XB77_MOCK_PROVER` | `1` | quitar | Skip nargo ZK generation |
| `XB77_ARB_RPC` | `http://127.0.0.1:8545` | Sepolia RPC URL | EVM RPC endpoint |
| `XB77_ANCHOR_ADDR` | Anvil default | Sepolia address | `anchor.zig` contract |
| `XB77_SETTLEMENT_ADDR` | Anvil default | Sepolia address | `settlement_engine.zig` |
| `XB77_ZK_VERIFIER_ADDR` | Anvil default | Sepolia address | `zk_verifier.zig` |

---

## Lo que sí está validado 100%

- **TCP framing AWP**: 4-byte LE header, burst de N mensajes, WriteFailed correcto
- **settle AWP → on-chain**: `ArbitrumAdapter.settlePayment()` → tx Anvil confirmada (cast tx verificado)
- **anchor_root AWP → on-chain**: `ArbitrumAdapter.anchorStateRoot()` → `getRoot()` retorna `0xdede...` post-anchor
- **WASM contracts**: los 3 pasan Nitro validation (`--estimate-gas --no-verify`, EXIT:0)
- **BN254 WASM**: 63/63 tests, Miller loop, Groth16 completo
- **Crypto**: secp256k1, Keccak256, `signEthMessage()` presente
- **Selectores ABI**: todos verificados (`keccak4()` comptime, TypeScript SDK en sync)
- **Git history**: 5 commits con author correcto (`195769325+dzkinha@users.noreply.github.com`)
