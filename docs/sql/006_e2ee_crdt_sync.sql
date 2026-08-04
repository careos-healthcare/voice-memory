-- Metadata-only CRDT relay fields. encrypted_payload remains opaque ciphertext.
ALTER TABLE sync_blobs ADD COLUMN IF NOT EXISTS device_id text;
ALTER TABLE sync_blobs ADD COLUMN IF NOT EXISTS vector_clock jsonb;
ALTER TABLE sync_blobs
  ADD COLUMN IF NOT EXISTS key_epoch integer NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS sync_blobs_device_idx
  ON sync_blobs (user_id, device_id, updated_at DESC);
