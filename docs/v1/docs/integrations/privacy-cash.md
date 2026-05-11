---
pageClass: is-legacy-page
---
# Privacy Cash Integration

**Status:** ![Active](https://img.shields.io/badge/Status-Active-brightgreen)
**Role:** Transaction Obfuscation & Breaking Links

While ShadowWire protects the *content* of a transaction, Privacy Cash is designed to break the *timing and clustering* analysis. It functions as a mixer-like protocol that aggregates multiple small flows into standardized denominations to maximize the anonymity set.

## The Obfuscation Layer

Privacy Cash sits between the Agent's Treasury and the final payment execution.

- **Standardization:** All internal movements are broken down into standard amounts (e.g., 10, 100, 1000 USDC). This makes all transactions look identical on-chain.
- **Relayers:** Transactions are dispatched via a network of Relayers that pay the gas fees, dissociating the Agent's public wallet from the transaction execution.

## Integration with MCP
The Agent uses the `agent.privacy_cash.transfer` tool to route sensitive payments.

```typescript
// MCP Tool Execution
await useTool('agent.privacy_cash.transfer', {
    amount: 500,
    recipient: 'vendor_address',
    obfuscationLevel: 'HIGH'
});
```

This tool automatically calculates the optimal breakdown of denominations and routes them through the Privacy Cash protocol.
