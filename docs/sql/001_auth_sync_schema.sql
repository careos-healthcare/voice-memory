-- VoiceMemory durable auth + encrypted sync schema
-- Apply manually or via lib/server/db.ts ensureDatabaseSchema()

CREATE TABLE IF NOT EXISTS auth_codes (
  email text PRIMARY KEY,
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_codes_expires_at_idx ON auth_codes (expires_at);

ALTER TABLE auth_codes ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL,
  email text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions (user_id);
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions (expires_at);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id text PRIMARY KEY,
  focus_area text NOT NULL DEFAULT 'General',
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sync_blobs (
  user_id text NOT NULL,
  blob_type text NOT NULL,
  blob_id text NOT NULL,
  encrypted_payload jsonb NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, blob_type, blob_id)
);

CREATE INDEX IF NOT EXISTS sync_blobs_user_updated_idx ON sync_blobs (user_id, updated_at DESC);
