// Minimal Solana JSON-RPC client for the browser.
//
// Only what the dApp needs to submit a transaction:
//   - getLatestBlockhash() → { blockhash, lastValidBlockHeight }
//   - sendRawTransaction(bytes) → signature (base58)
//   - getSignatureStatuses([sig...]) → array of {confirmationStatus, err} | null
//   - getAccountInfo(pubkeyBase58) → { lamports, owner, data, ... } | null
//   - getBalance(pubkeyBase58) → number (lamports)
//
// All calls use POST application/json against a configurable RPC URL.
// Default: window.XB77_RPC_URL or http://127.0.0.1:8899.
//
// Base58 encoding is from a minimal lib in ./base58.js — kept tiny on
// purpose (no big deps). Tx serialization happens in ./solana-tx.js.

(function () {
const DEFAULT_RPC = () =>
  (typeof globalThis !== "undefined" && globalThis.XB77_RPC_URL) ||
  "http://127.0.0.1:8899";

class SolanaRpcClient {
  constructor(url) {
    this.url = url || DEFAULT_RPC();
    this._id = 0;
  }

  async _call(method, params) {
    const id = ++this._id;
    const body = JSON.stringify({ jsonrpc: "2.0", id, method, params });
    const r = await fetch(this.url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    if (!r.ok) throw new Error(`solana-rpc ${method}: HTTP ${r.status}`);
    const j = await r.json();
    if (j.error) {
      const e = new Error(`solana-rpc ${method}: ${j.error.message || JSON.stringify(j.error)}`);
      e.code = j.error.code;
      e.data = j.error.data;
      throw e;
    }
    return j.result;
  }

  async getLatestBlockhash(commitment = "confirmed") {
    const r = await this._call("getLatestBlockhash", [{ commitment }]);
    return {
      blockhash: r.value.blockhash,
      lastValidBlockHeight: r.value.lastValidBlockHeight,
    };
  }

  /** Send pre-signed raw bytes. Returns the tx signature (base58). */
  async sendRawTransaction(rawBytes, { skipPreflight = false } = {}) {
    const b64 = btoa(String.fromCharCode(...rawBytes));
    return this._call("sendTransaction", [
      b64,
      { encoding: "base64", skipPreflight, preflightCommitment: "confirmed" },
    ]);
  }

  /** Returns an array aligned with `signatures`; entries are null if unknown. */
  async getSignatureStatuses(signatures, searchTransactionHistory = false) {
    const r = await this._call("getSignatureStatuses", [signatures, { searchTransactionHistory }]);
    return r.value;
  }

  /** Convenience: wait until the signature reaches `confirmed` or fail with err. */
  async confirmSignature(signature, { timeoutMs = 30_000, intervalMs = 400 } = {}) {
    const t0 = Date.now();
    while (Date.now() - t0 < timeoutMs) {
      const [s] = await this.getSignatureStatuses([signature]);
      if (s) {
        if (s.err) throw new Error(`tx ${signature} failed: ${JSON.stringify(s.err)}`);
        if (s.confirmationStatus === "confirmed" || s.confirmationStatus === "finalized") return s;
      }
      await new Promise((res) => setTimeout(res, intervalMs));
    }
    throw new Error(`tx ${signature} not confirmed within ${timeoutMs}ms`);
  }

  async getAccountInfo(pubkeyBase58, commitment = "confirmed") {
    const r = await this._call("getAccountInfo", [pubkeyBase58, { encoding: "base64", commitment }]);
    if (!r.value) return null;
    const [b64, _enc] = r.value.data;
    const data = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return {
      lamports: r.value.lamports,
      owner: r.value.owner,
      executable: r.value.executable,
      rentEpoch: r.value.rentEpoch,
      data,
    };
  }

  async getBalance(pubkeyBase58, commitment = "confirmed") {
    const r = await this._call("getBalance", [pubkeyBase58, { commitment }]);
    return r.value;
  }

  async requestAirdrop(pubkeyBase58, lamports) {
    return this._call("requestAirdrop", [pubkeyBase58, lamports]);
  }

  // Returns an array of { pubkey, account: { data: Uint8Array, owner, lamports, ... } }
  async getProgramAccounts(programIdBase58, { commitment = "confirmed", dataSize } = {}) {
    const filters = [];
    if (typeof dataSize === "number") filters.push({ dataSize });
    const params = [programIdBase58, { encoding: "base64", commitment, filters }];
    const r = await this._call("getProgramAccounts", params);
    if (!Array.isArray(r)) return [];
    return r.map((entry) => {
      const b64 = (entry.account.data && entry.account.data[0]) || "";
      const data = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
      return {
        pubkey: entry.pubkey,
        account: {
          data,
          owner: entry.account.owner,
          lamports: entry.account.lamports,
          executable: entry.account.executable,
        },
      };
    });
  }
}

const _SolanaRpc = {
  create(url) { return new SolanaRpcClient(url); },
  Client: SolanaRpcClient,
};

if (typeof globalThis !== "undefined") globalThis.SolanaRpc = _SolanaRpc;
})();
