-- xB77 Sovereign Billing Schema (Cloudflare D1)

CREATE TABLE IF NOT EXISTS credits (
    wallet_address TEXT PRIMARY KEY,
    credits_balance INTEGER DEFAULT 0,
    tier TEXT DEFAULT 'free',
    status TEXT DEFAULT 'active',
    last_update INTEGER
);

CREATE TABLE IF NOT EXISTS billing_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wallet_address TEXT,
    amount INTEGER,
    reason TEXT,
    timestamp INTEGER,
    FOREIGN KEY(wallet_address) REFERENCES credits(wallet_address)
);

-- Seed data for testing
INSERT OR IGNORE INTO credits (wallet_address, credits_balance, tier, status, last_update) 
VALUES ('cfo_alpha_pubkey', 5000, 'paid', 'active', 1715616000000);

-- Migration 0042: Webhooks salientes
CREATE TABLE IF NOT EXISTS webhooks (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    url TEXT NOT NULL,
    secret TEXT NOT NULL,
    event_aliases TEXT, -- JSON string
    status TEXT DEFAULT 'active',
    created_at INTEGER
);

CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id TEXT PRIMARY KEY,
    webhook_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    next_attempt_at INTEGER,
    last_status INTEGER,
    last_error TEXT,
    FOREIGN KEY(webhook_id) REFERENCES webhooks(id)
);
