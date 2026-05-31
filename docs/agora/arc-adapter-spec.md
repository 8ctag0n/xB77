# Arc Adapter Specification

## 1. Goal
Implement the `ChainProvider` interface for the Arc Network using Circle SDK.

## 2. Interface Mapping
| Method | Implementation Detail |
|--------|-----------------------|
| `get_balance` | Calls Circle Gateway or Wallets API for USDC balance. |
| `send_tx` | Uses Circle Wallets for signing and broadcasting. Supports `transfer` (USDC). |
| `get_address` | Returns the Circle Wallet address associated with the agent. |

## 3. Circle Modules
- `wallets.zig`: Authentication and basic wallet management.
- `cctp.zig`: Cross-chain routing logic.
- `gateway.zig`: Unified balance check.
- `paymaster.zig`: Gasless/USDC-fee abstraction.
- `usyc.zig`: Yield management.

## 4. Dependencies
- `core/mesh/http.zig`: For REST API calls to Circle.
- `core/protocol/types.zig`: For common types.
- `core/security/crypto.zig`: For signing if needed (though Circle Wallets often handles this server-side).
