import { Database } from 'bun:sqlite';
import type { PaymentReceipt, ReceiptStore } from './receipts';

export class SQLiteReceiptStore implements ReceiptStore {
  private db: Database;

  constructor(dbPath: string = 'agent.db') {
    this.db = new Database(dbPath);
    this.init();
  }

  private init() {
    // Crear tabla si no existe
    this.db.run(`
      CREATE TABLE IF NOT EXISTS receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT,
        recipient TEXT,
        token TEXT,
        amount REAL,
        type TEXT,
        provider TEXT,
        metadata TEXT,
        proofPda TEXT,
        nonce INTEGER,
        txSignature TEXT,
        timestamp INTEGER,
        raw_json TEXT
      )
    `);
    
    // Attempt migration for existing tables (ignore errors if columns exist)
    try { this.db.run("ALTER TABLE receipts ADD COLUMN provider TEXT"); } catch {}
    try { this.db.run("ALTER TABLE receipts ADD COLUMN metadata TEXT"); } catch {}
  }

  async recordPayment(receipt: PaymentReceipt): Promise<void> {
    const query = this.db.prepare(`
      INSERT INTO receipts (
        sender, recipient, token, amount, type, provider, metadata,
        proofPda, nonce, txSignature, timestamp, raw_json
      ) VALUES (
        $sender, $recipient, $token, $amount, $type, $provider, $metadata,
        $proofPda, $nonce, $txSignature, $timestamp, $raw_json
      )
    `);

    query.run({
      $sender: receipt.sender,
      $recipient: receipt.recipient,
      $token: receipt.token,
      $amount: receipt.amount,
      $type: receipt.type,
      $provider: receipt.provider || 'unknown',
      $metadata: receipt.metadata ? JSON.stringify(receipt.metadata) : null,
      $proofPda: receipt.proofPda || null,
      $nonce: typeof receipt.nonce === 'bigint' ? Number(receipt.nonce) : (receipt.nonce || null),
      $txSignature: receipt.txSignature || null,
      $timestamp: receipt.timestamp,
      $raw_json: JSON.stringify(receipt) // Respaldo completo por si acaso
    });
    
    console.log(`[SQLite] Receipt stored. ID: ${receipt.txSignature?.slice(0, 8)}...`);
  }

  async listReceipts(limit: number = 25): Promise<PaymentReceipt[]> {
    const query = this.db.prepare(`
      SELECT * FROM receipts ORDER BY timestamp DESC LIMIT $limit
    `);
    
    const rows = query.all({ $limit: limit }) as any[];
    
    return rows.map(row => ({
      sender: row.sender,
      recipient: row.recipient,
      token: row.token,
      amount: row.amount,
      type: row.type,
      provider: row.provider,
      metadata: row.metadata ? JSON.parse(row.metadata) : undefined,
      proofPda: row.proofPda,
      nonce: row.nonce,
      txSignature: row.txSignature,
      timestamp: row.timestamp
    }));
  }

  async getLatestReceipt(): Promise<PaymentReceipt | null> {
    const query = this.db.query(`
      SELECT * FROM receipts ORDER BY timestamp DESC LIMIT 1
    `);
    
    const row = query.get() as any;
    if (!row) return null;

    return {
      sender: row.sender,
      recipient: row.recipient,
      token: row.token,
      amount: row.amount,
      type: row.type,
      provider: row.provider,
      metadata: row.metadata ? JSON.parse(row.metadata) : undefined,
      proofPda: row.proofPda,
      nonce: row.nonce,
      txSignature: row.txSignature,
      timestamp: row.timestamp
    };
  }
  
  // Método extra para debugging
  close() {
    this.db.close();
  }
}
