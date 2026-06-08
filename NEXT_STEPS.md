# xB77 — Próximos pasos

Estado actual: BN254 optimal Ate pairing 100% funcional en Zig puro/WASM.
46/46 tests verdes. Zero precompile calls. Listo para construir encima.

---

## Fase 4 — Groth16 verifier on-chain (prioridad máxima, Open House)

### 4.1 groth16.zig

Función central:

```zig
pub fn verify(vk: VerifyingKey, proof: Proof, pub_inputs: []const G1) bool {
    // 1. MSM: L = sum_i a_i * vk.gamma_abc[i+1]  (inputs públicos)
    // 2. L = vk.gamma_abc[0] + L
    // 3. Check: e(proof.a, proof.b)
    //         * e(-vk.alpha, vk.beta)
    //         * e(-L, vk.gamma)
    //         * e(-proof.c, vk.delta)  == Fp12.ONE
}
```

Tipos necesarios:
```zig
const Proof = struct { a: G1, b: G2, c: G1 };
const VerifyingKey = struct {
    alpha: G1, beta: G2, gamma: G2, delta: G2,
    gamma_abc: []const G1,   // longitud = n_public + 1
};
```

MSM naive primero (loop de scalarMul + addJac) — suficiente para la demo.
Optimizar con Pippenger después si el gas lo justifica.

### 4.2 Calldata parsing

Formato compatible con el verifier estándar de Solidity (snarkjs output):
```
proof.a    — 64 bytes  (G1 affine, EIP-196)
proof.b    — 128 bytes (G2 affine, EIP-197)
proof.c    — 64 bytes  (G1 affine)
pub_inputs — 32 bytes * n
```

### 4.3 Entry point Stylus (src/lib.rs → user_entrypoint en Zig)

Decisión pendiente: ¿entry point en Rust thin wrapper o directo en Zig?
Recomendación: Rust thin wrapper que llama `extern "C"` al Zig — más compatible
con cargo-stylus toolchain actual.

```rust
// src/lib.rs — thin wrapper
#[no_mangle]
pub extern "C" fn user_entrypoint(len: usize) -> usize {
    // lee calldata, llama groth16_verify() del Zig, escribe result
}
```

### 4.4 Benchmark de gas

Medir vs precompilado EVM estándar (ecPairing ~45k gas por par = ~180k total para Groth16).
Ese delta es el corazón de la propuesta de grant.

Comando de referencia:
```bash
cast send <contract> "verifyProof(bytes)" <proof_hex> --gas-limit 5000000
```

---

## Fase 5 — Post Open House: repo público + grant

### 5.1 Separación en crypto-zig

```
crypto-zig/
├── src/
│   ├── bn254/          ← mover de acá
│   │   ├── fp.zig
│   │   ├── fp2.zig
│   │   ├── fp6.zig
│   │   ├── fp12.zig
│   │   ├── g1.zig
│   │   ├── g2.zig
│   │   └── pairing.zig
│   ├── groth16/
│   │   └── verifier.zig
│   └── poseidon/       ← Fase 6
└── bindings/
    ├── js/
    ├── python/
    └── rust/
```

### 5.2 Grant Arbitrum Stylus

Propuesta con:
- Código funcionando (no promesas)
- Benchmark real: X gas vs 180k gas EVM
- Roadmap concreto (multicadena, wrappers)
- Demo en vivo del Open House como prueba

Programas a mirar:
- Arbitrum Foundation Grants (grants.arbitrum.foundation)
- Stylus Sprint (si sigue activo)
- Uniswap Foundation (si hay componente AMM/DeFi)

---

## Fase 6 — Expansión de primitivas

Orden por impacto/esfuerzo:

### 6.1 Poseidon hash
ZK-friendly, nativo del ecosistema Circom/iden3.
Reemplaza Keccak dentro de circuitos. Alta demanda.

### 6.2 EdDSA / BabyJubJub
Curva embebida en BN254. Verificación de firmas on-chain.
Usado en Semaphore, Tornado, Hermez.
Reutiliza ~90% de la aritmética de G1 ya implementada.

### 6.3 BLS12-381
Curva de Ethereum 2.0, Filecoin, Zcash.
Misma estructura de torre que BN254 — el código se adapta.
Abre mercado de proyectos ETH2/restaking.

### 6.4 PLONK verifier
Sucesor de Groth16 sin trusted setup por circuito.
Más complejo pero más futuro.

### 6.5 SHA-256 / Keccak optimizados
Para verificadores que hashean inputs fuera del circuito.

---

## Fase 7 — Wrappers multicadena y multilenguaje

### Cadenas objetivo
```
Arbitrum Stylus    ← ya (Fase 4)
ink! (Polkadot)    ← mismo WASM, distinto ABI de host
Near               ← WASM nativo
CosmWasm           ← WASM nativo
zkSync             ← LLVM/WASM compatible
```

### Wrappers de lenguaje
```
TypeScript/JS   ← reemplazar snarkjs en frontend/Node
Python          ← research, tooling, scripts
Rust            ← FFI o crate wrapper sobre el .wasm
Go              ← via wasmtime, ecosistema gnark/go-ethereum
```

El pitch: un solo core en Zig, máxima performance, cero overhead de runtime,
accesible desde cualquier lenguaje y deployable en cualquier cadena WASM.

---

## Notas técnicas para retomar

**Bug histórico documentado:**
El NAF de 6t+2 tiene 66 dígitos (MSB en posición 65 por carry propagation),
no 64. Requiere 65 iteraciones de Miller loop. Ver commit 3abf0fc.

**finalExpHard:**
Algorithm 6, Duquesne-Ghammam 2015. Matchea gnark-crypto exactamente.
No usar la versión "Fuentes-Castañeda" que circula en varios repos — está mal.

**Frobenius constants:**
Todas derivadas de ξ^{(p-1)/6} vía test diagnóstico en fp6.zig.
GAMMA_1_1, GAMMA_1_2, DELTA_1, DELTA_3, DELTA_4 verificadas contra gnark.

**Nitro local:**
Binario nativo en /usr/local/bin/nitro, machines en /home/user/target/machines/
Ver docker-compose.yml para el comando de arranque sin Docker.

**cargo-stylus:**
v0.10.7 instalado. `cargo stylus deploy` desde la raíz del repo.
Cargo.toml + Stylus.toml + src/lib.rs son el scaffolding de deploy.
