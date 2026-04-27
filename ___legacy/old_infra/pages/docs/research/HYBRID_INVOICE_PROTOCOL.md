# xB77 Hybrid Invoice Protocol (HIP)
**Version:** 1.0 (Draft)
**Status:** Experimental
**Author:** xB77 Research Team

## 1. Abstract

Cryptographic privacy protocols (like Light Protocol or Tornado Cash) historically suffer from the "Accounting Black Hole" problem: while they successfully obfuscate the transaction graph, they inevitably destroy the semantic context of the transfer (metadata, invoices, tax details). This renders them unusable for compliant enterprise operations.

**xB77 HIP** (Hybrid Invoice Protocol) is a layer-2 standard for embedding encrypted, schema-validated fiscal metadata directly into the shielded state transition, enabling **"Self-Generating Accounting"** without compromising the privacy set.

## 2. The Architecture

The protocol decouples the **Settlement Layer** (Value Transfer) from the **Semantic Layer** (Data Transfer), but binds them atomicity within a single transaction.

### 2.1. The Data Structure (UBL-Light)

We utilize a compressed binary variant of the **Universal Business Language (UBL 2.1)** standard.

```json
{
  "ver": 1,
  "iv": "x9f...a2", // Initialization Vector
  "payload": "ENCRYPTED_BLOB",
  "hash": "0x...ff" // Binding Hash to the ZK-Proof Public Inputs
}
```

### 2.2. Encryption Scheme

We employ a **Hybrid Encryption Scheme (ECIES)** using the recipient's Solana Public Key (converted to Curve25519) to derive a shared secret.

1.  **Key Exchange:** `SharedSecret = ECDH(SenderPriv, ReceiverPub)`
2.  **Symmetric Key:** `K = HKDF(SharedSecret)`
3.  **Encryption:** `Ciphertext = AES-256-GCM(InvoiceJSON, K, IV)`

This ensures that **only** the sender and the receiver (and any holder of a Viewing Key) can reconstruct the accounting context.

## 3. The Lifecycle

### Phase 1: Emission (The Sender Agent)
1.  **Context Construction:** The Agent generates the payment (e.g., 50,000 USDC) and the invoice data (Items, VAT, Vendor ID).
2.  **Metadata Embedding:** The invoice data is serialized and encrypted.
3.  **State Compression:** The encrypted blob is stored as a **Compressed State** (or ephemeral Memo) in Light Protocol, atomically linked to the value transfer UTXO.

### Phase 2: Transmission (The Dark Forest)
On-chain, observers see only:
*   A ZK validity proof.
*   Two nullifiers (spent notes).
*   Two new commitments (output notes).
*   **No visible amount, no recipient, no invoice data.**

### Phase 3: Reconstruction (The Receiver Agent)
1.  **Scanning:** The Receiver's "Listener" scans the chain using its `IncomingViewKey`.
2.  **Detection:** It identifies a UTXO belonging to it.
3.  **Extraction:** It retrieves the associated encrypted metadata state.
4.  **Decryption:** Using the Wallet's `PrivateKey`, it decrypts the blob back into the UBL JSON.
5.  **Reconciliation:** The system validates that `Invoice.total == UTXO.amount`. If valid, it triggers the "Invoice Received" event in the Hub.

## 4. Compliance & Selective Disclosure

The "Killer Feature" for institutional adoption is the **Audit Key**.

An enterprise can share a specific `AuditViewKey` with a regulator or auditor. This key allows **read-only access** to decrypt the metadata (Invoices) without giving the ability to spend funds. This turns a "Dark Wallet" into a "Transparently Compliant Vault" instantly.

## 5. Implementation Status

*   [x] **Mock Implementation:** SQLite storage with simulated encryption (Live in Hub).
*   [ ] **On-Chain Integration:** Light Protocol custom PDA for metadata storage.
*   [ ] **Standardization:** Defining the compact-UBL schema for Solana.

---
*Built with ❤️ for the Solana Privacy Hackathon 2026.*
