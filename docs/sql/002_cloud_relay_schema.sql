-- Zero-knowledge relay metadata and opaque ciphertext queues.
-- The vault hash is a server-salted HMAC; no account identifier or plaintext
-- archive content is stored in these tables.

CREATE TABLE IF NOT EXISTS cloud_relay_devices (
  vault_hash TEXT NOT NULL,
  device_id TEXT NOT NULL,
  last_active_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (vault_hash, device_id)
);

CREATE TABLE IF NOT EXISTS cloud_relay_envelopes (
  vault_hash TEXT NOT NULL,
  envelope_id TEXT NOT NULL,
  source_device_id TEXT NOT NULL,
  target_device_id TEXT NOT NULL,
  envelope JSONB NOT NULL,
  byte_length INTEGER NOT NULL CHECK (byte_length > 0 AND byte_length <= 262144),
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (vault_hash, envelope_id, target_device_id)
);

CREATE INDEX IF NOT EXISTS cloud_relay_envelopes_delivery_idx
  ON cloud_relay_envelopes (vault_hash, target_device_id, created_at);

CREATE INDEX IF NOT EXISTS cloud_relay_envelopes_expiry_idx
  ON cloud_relay_envelopes (expires_at);

