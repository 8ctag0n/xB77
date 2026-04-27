# WEEK PLAN S8: MULTI-CHAIN ASCENSION

**Estado:** Solana HFT funcional. Persistencia activa. Visión soberana definida.
**Meta:** Habilitar Ethereum/EVM y sentar las bases de Bitcoin Light Node.

## 🏁 Prioridades Inmediatas (Hackathon Ready)

1. **[EVM Crypto]**: Implementar Secp256k1 y Keccak256 en `core/crypto.zig`. Es el bloqueador principal para ETH/BTC.
2. **[EVM Client]**: Desarrollar el cliente RPC para Ethereum/Base en `core/evm.zig` (Get Nonce, Gas Price).
3. **[EVM Tx]**: Implementar el constructor de transacciones EIP-1559 en `core/tx.zig`.
4. **[AgentKit Bridge]**: Crear un adaptador para que el Engine pueda orquestar acciones de Coinbase AgentKit.

## 🛠️ Tareas Técnicas / Deuda

- [ ] Integrar el nuevo `RiskScorer` (0.11% tax) en los flujos de EVM.
- [ ] Refactorizar `Vault` para manejar llaves Secp256k1 en paralelo a Ed25519.
- [ ] Prototipar el Verificador en Arbitrum Stylus (Zig to WASM).

## 🚀 Vision Milestones (Pre-Bitcoin)

- **Dual Identity**: ✅ El agente muestra su dirección de Solana y Ethereum en el comando `status`.
- **EVM Direct Pay**: Primer pago exitoso en Base Devnet desde el CLI de Zig.
- **ZK-Verification**: Validar la primera ZK-Factura generada en una transacción de Base.

## Métricas de Éxito
- Soporte nativo Secp256k1 sin dependencias externas pesadas.
- Binario WASM compatible con Cloudflare Workers incluyendo lógica EVM.
- Latencia de firma Secp256k1 < 10ms.
