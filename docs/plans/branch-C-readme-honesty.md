# Rama C — `feat/readme-honesty`

> Plan ejecutable · no aplicado · enfoque **núcleo chain-agnostic** + honestidad ·
> Maestro: [../MULTICHAIN-DOCS-PLAN.md](../MULTICHAIN-DOCS-PLAN.md)

## Archivos que esta rama posee (exclusivos — no los tocan A ni B)
- `README.md`
- `README-ARC.md` / `README-SUI.md` (solo referencias/links desde README, sin moverlos)

> ⚠️ Nada de `docs/` (rama A) ni `webapp_deploy/` (rama B).

## Cambios

### `README.md`
1. **Tagline (≈l.8-9):**
   - `Shielded payments · ZK-compressed receipts · autonomous agents on Solana.`
   - → `Shielded payments · ZK-compressed receipts · sovereign agents across Solana, Arc & Sui.`
2. **Badges:** `Settlement: Solana` → `Settlement: Solana · Arc · Sui` (o 3 badges de cadena).
   Mantener badges de Zig / Rust.
3. **Sección "The xB77 Editions":** ya está bien — verificar que los 3 editions queden parejos y
   que Sui mencione el respaldo real (package `sovereign` publicado + PTBs).
4. **Frase final:** ya dice "Built for Solana Frontier, Agora Arc, and Sui Overflow" → OK.

## HONESTIDAD (núcleo de esta rama)
Pasada sobre el README para alinear claims con lo que corre hoy:
- **Verifier ZK:** donde se sugiera verificación criptográfica on-chain completa, aclarar que
  el verifier on-chain hoy es structural stub; la verificación cripto completa es roadmap.
  (El whitepaper §8 ya lo documenta — mantener coherencia.)
- **2.011% "cryptographically enforced":** matizar — el circuito lo compromete, pero el
  facilitator/economía está en placeholder (`agent.toml` facilitator = `1`s). Presentar como
  diseño enforced-by-design, no como flujo de fondos en producción.
- Tono: bajar un punto el hype ("God Mode" etc. pueden quedar, pero que la sustancia real —
  multichain con código en cada cadena, ZK honesto— hable más fuerte).

## Validación
- `grep -in "on Solana" README.md` → 0 (salvo donde Solana sea legítimamente el adaptador de referencia).
- Links a README-ARC.md / README-SUI.md funcionan.
- Claims de verifier y 2.011% coinciden con el tono honesto del whitepaper §8.

## Git
```
git checkout main && git pull
git checkout -b feat/readme-honesty
# … cambios …
git add README.md
git commit
```
