# ERC-7715 sobre SovereignPolicy

**Estado:** Implementado  
**Prioridad:** Alta — distribución via wallets estándar sin integración custom  
**Investigado:** 2026-06-02 | **Actualizado:** 2026-06-02

---

## Contexto

ERC-7715 (`wallet_grantPermissions`) es el estándar convergente para permisos de agentes en wallets Web3. Lo co-autorearon ZeroDev, MetaMask, Coinbase, WalletConnect y Biconomy. En mid-2026, todos esos wallets tienen soporte experimental o completo.

**El insight clave:** `SovereignPolicy.validateUserOp` ya tiene la firma que ZeroDev/ERC-7715 requiere para enforcement. El gap no es de contratos — es de interfaz de SDK y un contrato para el segundo path (MetaMask).

Si se implementa, `SovereignPolicy` se convierte en el backend de semantic enforcement para cualquier wallet ERC-7715. El usuario hace el grant desde su wallet habitual — la constitución Stylus corre por debajo sin que nadie tenga que conocer xB77.

---

## Cómo funciona ERC-7715 (lo relevante)

ERC-7715 es un estándar JSON-RPC de wallet, no de contrato. El enforcement on-chain va por uno de dos caminos:

**Path A — ZeroDev/Coinbase (el que xB77 ya usa):**
```
wallet_grantPermissions
  → permissionContext (opaque bytes con session key + policy address + policyData)
  → en cada UserOp: validateUserOp(userOpHash, sig, policyData) en el policy contract
```

**Path B — MetaMask/ERC-7710:**
```
wallet_grantPermissions
  → permissionContext (Delegation chain con Caveats)
  → en cada call: DelegationManager → ICaveatEnforcer.beforeHook(terms, args, ...)
```

---

## Por qué xB77 ya está cerca (Path A)

`SovereignPolicy.validateUserOp` ya tiene la firma correcta:

```solidity
function validateUserOp(
    bytes32,                   // userOpHash
    bytes calldata,            // kernelSignature
    bytes calldata policyData  // intent vector (512 bytes) fijado al momento del grant
) external view returns (uint256) {
    (bool approved,) = _callStylusValidate(policyData[0:512]);
    return approved ? 0 : 1;
}
```

Lo que falta es que el SDK use `wallet_grantPermissions` en vez de construir el Kernel client directo, para que cualquier wallet ERC-7715 pueda hacer el grant sin integración custom.

---

## Tasks — ordenados por impacto

### 1. SDK: `grantPermissions()` con viem ERC-7715 (~1 día)

Agregar en `XB77ArbitrumClient`:

```typescript
async grantPermissions(
  walletClient: WalletClient,
  sessionKeyPubkey: Hex,
  intentVector: IntentVector,
  opts?: { expiry?: number }
): Promise<{ context: Hex }> {
  return walletClient.grantPermissions({
    expiry: opts?.expiry ?? Math.floor(Date.now() / 1000) + 86_400,
    signer: { type: "key", data: { publicKey: sessionKeyPubkey } },
    permissions: [{
      type: "semantic-intent",
      data: { intentVector: encodeIntentVector(intentVector) },
    }],
  });
}
```

El `permissionContext` resultante reemplaza el flow actual de `toPermissionValidator` directo. Cualquier wallet que soporte ERC-7715 puede hacer el grant desde su UI nativa.

### 2. Definir schema del tipo `"semantic-intent"` (~2h)

Schema JSON para el tipo custom:

```typescript
// sdk/ts/src/arbitrum.ts — agregar junto a los selectores
export const SEMANTIC_INTENT_PERMISSION_TYPE = "semantic-intent" as const;

export interface SemanticIntentPermissionData {
  intentVector: Hex;        // 512 bytes, int32[128] ABI-packed
  expirySeconds?: number;   // default 86400 (24h)
}
```

Documentar en el registry de tipos de `wallet_grantPermissions` para que wallets puedan mostrar texto legible en su UI: *"Este agente tiene permiso de operar con intent vector [neutral/restrictivo/etc.]"*

### 3. `SovereignCaveatEnforcer.sol` — Path B MetaMask (~1 día)

Nuevo contrato en `onchain/evm/src/`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICaveatEnforcer {
    function beforeHook(
        bytes calldata terms,
        bytes calldata args,
        bytes32 mode,
        bytes calldata executionCallData,
        bytes32 delegationHash,
        address delegationManager,
        address sender
    ) external;
}

contract SovereignCaveatEnforcer is ICaveatEnforcer {
    uint32 private constant SEL_VALIDATE_SEMANTIC = 0xabcdef01;

    error SemanticViolation();

    // terms = abi.encode(constitutionStylusAddress) — estático, fijado al grant
    // args  = abi.encode(intentVector)              — dinámico, por call
    function beforeHook(
        bytes calldata terms,
        bytes calldata args,
        bytes32,
        bytes calldata,
        bytes32,
        address,
        address
    ) external override {
        address constitution = abi.decode(terms, (address));
        bytes memory vector  = abi.decode(args, (bytes));
        require(vector.length >= 512, "bad vector");

        bytes memory payload = abi.encodePacked(SEL_VALIDATE_SEMANTIC, vector);
        (bool success, bytes memory result) = constitution.staticcall(payload);

        if (!success || result.length < 32 || abi.decode(result, (uint256)) != 1) {
            revert SemanticViolation();
        }
    }
}
```

Con este contrato, MetaMask puede incluir `SovereignCaveatEnforcer` como caveat en su Delegation Toolkit. Los usuarios con MetaMask hacen el grant exactamente igual que con ZeroDev.

### 4. xB77 cross-chain root (~2 días)

xB77 ya tiene bridge verify multi-chain. `buildCrossChainRoot()` permite construir un Merkle root que cubre Arbitrum + Solana + Sui y puede acompañar el grant como metadato:

```typescript
// Construir root que cubre múltiples chains
const root = buildCrossChainRoot([
  { chainId: 421614, account: arbitrumGuardAddress },
  { chainId: XB77_CHAIN.SOLANA, account: solanaPeerHash },
]);
// root es verificable on-chain via isBridgeAgentTrusted() en SovereignPolicy
```

**Nota:** `buildCrossChainRoot()` es una utilidad xB77 — no está estandarizada en ningún ERC. ERC-7779 trata sobre storage collision prevention en migración de smart accounts (EIP-7702), no sobre permisos multi-chain.

Encaja directamente con `isBridgeAgentTrusted()` que ya existe en `SovereignPolicy`.

---

## Ecosistema (mid-2026)

| Wallet | Path | Estado ERC-7715 |
|--------|------|----------------|
| ZeroDev Kernel | A (validateUserOp) | Completo — co-autor |
| Coinbase Smart Wallet | A (validateUserOp) | Completo |
| MetaMask | B (ICaveatEnforcer) | Experimental Snap |
| WalletConnect/Reown | A | Soporte en AppKit |
| Biconomy Nexus | A (ERC-7579 module) | Completo |

Viem: `walletClient.grantPermissions()` disponible en namespace experimental (`viem/experimental`).

---

## Lo que NO hay que cambiar

`SovereignPolicy.validateUserOp` ya es correcto — no tocar.  
El Stylus constitution contract no necesita cambios.  
Los guards (AaveGuard, GMXGuard) no necesitan cambios.
