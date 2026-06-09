# xB77 — Estado real del stack (Open House sprint)

> Documento generado post-sesión de debugging profunda.  
> Fecha: 2026-06-09 | Rama: devstylus | Commit base: 8770094

---

## TL;DR honesto

El stack tiene tres capas bien diferenciadas en términos de madurez:

| Capa | Estado |
|------|--------|
| **WASM on-chain** (Stylus contracts) | Completos, validados, no desplegados |
| **Bridge AWP → chain** (settle, anchor) | Conectados y probados contra Anvil |
| **Generación de pruebas ZK** | Mockeada (`XB77_MOCK_PROVER=1`) |
| **Firma de transacciones** | Sin firmar (`eth_sendTransaction`, solo Anvil) |
| **Deploy en Sepolia** | Bloqueado (wallet ops sin ETH) |

---

## Tabla completa de stubs

| # | Stub | Archivo:línea | Qué falsifica | ¿Existe implementación real? | Costo para producción |
|---|------|---------------|---------------|------------------------------|-----------------------|
| 1 | `verifyZkProof()` en bridge | `core/mesh/znode_bridge.zig:57-61` | `proof.len >= 64 → true` | ✅ `onchain/stylus/zk_verifier.zig` (UltraPlonk+Groth16 completo) + `ArbitrumAdapter.verifyZKProof()` ya codificado | Conectar: 5 líneas igual que `.settle` |
| 2 | Prueba ZK individual (`XB77_MOCK_PROVER=1`) | `core/kernel/prover.zig:40-46` | Imprime "MOCK_MODE: verified" sin ejecutar nargo | ✅ `circuits/zk_receipt/` (7 circuitos Noir), `scripts/nargo.sh` | Instalar nargo + quitar guard |
| 3 | Batch anchor en prover | `core/kernel/prover.zig:139-143` | Imprime `mock_batch_anchor_sig_777...` | ✅ `ArbitrumAdapter.anchorStateRoot()` ya funciona (bridge lo llama), `onchain/stylus/anchor.zig` completo | Llamar `ArbitrumAdapter.anchorStateRoot()` desde prover |
| 4 | `sendTx` sin firma | `core/chain/evm.zig:111-130` | `eth_sendTransaction` (cuenta desbloqueada Anvil) | ✅ `core/security/crypto.zig:146` tiene `signEthMessage(hash, sk)` y ECDSA secp256k1 | Escribir capa RLP tx + usar `eth_sendRawTransaction` |
| 5 | `canOperate()` bypass | `XB77_DEMO=1` → `core/kernel/orchestrator.zig:129` | Retorna `true` sin verificar balance | ✅ `syncBalance()` hace llamada HTTP real al Gateway; billing logic existe | Configurar Gateway URL + fondear wallet ops |
| 6 | `constitution.similarity` | `core/chain/arbitrum_adapter.zig:113` | `.similarity = 0` siempre | Parcial — `check_constitution()` hace RPC real, `approved` correcto; solo similarity no parseado | Parsear segundo word del ABI return |
| 7 | Stylus en Sepolia | — | Stubs Solidity en Anvil (`/tmp/xb77_stubs/`) | ✅ Los 3 contratos pasan `cargo stylus check --no-verify` | Fondear `0x64a33...b02` con ~0.02 Sepolia ETH; `deploy.sh deploy` |
| 8 | Nonces / gas en EVM client | `core/chain/evm.zig` (sendTx no pasa gas) | Anvil maneja gas automáticamente | Parcial — se puede agregar `gas` field al JSON RPC | Agregar gasLimit al buildTx |

---

## Estado por opcode AWP

| Opcode | Hex | Bridge → local | Bridge → on-chain | Test automatizado |
|--------|-----|----------------|--------------------|-------------------|
| `zk_verify` | `0x1C` | ✅ decodifica, responde | ❌ stub `proof.len >= 64` | ❌ |
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

## Pasos para la competencia (Open House, 4 días)

### Día 0: prereqs (~2h)
1. **Fondear wallet ops**: `cast send 0x64a33493e335b611473434639f920853f2ce2b02 --value 0.05ether` desde cualquier cuenta Sepolia
2. `rustup target add wasm32-unknown-unknown` (ya hecho en dev env)
3. `cargo update` en `onchain/stylus/rust-shim/` (ya hecho)

### Día 1: Deploy a Sepolia (~3h)
```bash
cd onchain/stylus
./deploy.sh deploy  # 9 contratos, ~0.02 ETH total
# Output: XB77_ANCHOR_ADDR, XB77_SETTLEMENT_ADDR, XB77_ZK_VERIFIER_ADDR
export XB77_ANCHOR_ADDR=0x...
export XB77_SETTLEMENT_ADDR=0x...
export XB77_ZK_VERIFIER_ADDR=0x...
```

### Día 1: Conectar `zk_verify` on-chain (~30 min)
En `core/mesh/znode_bridge.zig`, reemplazar stub `verifyZkProof()` (líneas 57-61):
```zig
// Antes (stub):
fn verifyZkProof(proof: []const u8, package: []const u8) bool {
    if (proof.len < 64) return false;
    return true;
}

// Después (real — mismo patrón que .settle):
// En el handler .zk_verify, construir ArbitrumAdapter con STYLUS_ZK_VERIFIER_ADDR
// y llamar arb.verifyZKProof(msg.proof, msg.public_root)
```
`ArbitrumAdapter.verifyZKProof()` ya está completamente implementado en `arbitrum_adapter.zig:200-243`.

### Día 2: Firma de transacciones (~1 día)
- `signEthMessage()` existe en `core/security/crypto.zig:146`
- Falta: encoder RLP para raw tx (EIP-155 o EIP-1559)
- Target: `core/chain/evm.zig::sendTx` → construir raw tx → `eth_sendRawTransaction`
- Alternativa más rápida: usar library externa (alloy-rs via WASM, o simplificar a foundry-compatible hex encoding)

### Día 3: E2E contra Sepolia
```bash
XB77_ARB_RPC=https://sepolia-rollup.arbitrum.io/rpc \
XB77_ANCHOR_ADDR=0x... \
XB77_SETTLEMENT_ADDR=0x... \
XB77_ZK_VERIFIER_ADDR=0x... \
XB77_DEMO=1 \
./zig-out/bin/xb77 serve
```
Flujo completo (terminal 2):
```
SDK → zk_verify → anchor_root → settle (contra contratos reales en Sepolia)
```

### Día 4: Demo video + submission
- Grabar flujo: `./zig-out/bin/xb77 serve` → SDK envía burst de 3 opcodes → on-chain txs en Arbiscan
- Links: contract addresses, tx hashes, repo

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
