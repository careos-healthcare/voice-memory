-- Onboarding brain dump upload receipts (idempotent)

CREATE TABLE IF NOT EXISTS brain_dump_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  entry_id text NOT NULL,
  duration_seconds integer NOT NULL,
  encrypted_bytes bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS brain_dump_uploads_user_created_idx
  ON brain_dump_uploads (user_id, created_at DESC);
