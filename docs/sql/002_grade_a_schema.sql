-- VoiceMemory Grade A schema (idempotent) — mirrors lib/server/db.ts AUTH_SYNC_SCHEMA_STATEMENTS

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id text PRIMARY KEY,
  focus_area text NOT NULL DEFAULT 'General',
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api_usage (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  transcribe_count integer NOT NULL DEFAULT 0,
  analyze_count integer NOT NULL DEFAULT 0,
  atmosphere_count integer NOT NULL DEFAULT 0,
  attest_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
);

ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS atmosphere_count integer NOT NULL DEFAULT 0;
ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS attest_count integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS api_minute_usage (
  subject_key text NOT NULL,
  endpoint text NOT NULL,
  minute_key text NOT NULL,
  request_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, endpoint, minute_key)
);

CREATE TABLE IF NOT EXISTS openai_daily_spend (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  spend_micro_usd bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
);

CREATE TABLE IF NOT EXISTS billing_entitlements (
  user_id text PRIMARY KEY,
  stripe_customer_id text,
  stripe_subscription_id text,
  status text NOT NULL DEFAULT 'canceled',
  tier text NOT NULL DEFAULT 'free',
  subscription_end_date timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE billing_entitlements
  ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz;

CREATE TABLE IF NOT EXISTS revenuecat_user_mappings (
  user_id text PRIMARY KEY,
  app_user_id text NOT NULL UNIQUE,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS capture_attestations (
  token_jti text PRIMARY KEY,
  device_id text NOT NULL,
  ip_hash text NOT NULL,
  ua_hash text NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  use_count integer NOT NULL DEFAULT 0,
  max_uses integer NOT NULL DEFAULT 500
);

CREATE TABLE IF NOT EXISTS journal_entries (
  user_id text NOT NULL,
  entry_id text NOT NULL,
  payload jsonb NOT NULL,
  sync_status text NOT NULL DEFAULT 'synced',
  client_updated_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entry_id)
);

CREATE INDEX IF NOT EXISTS journal_entries_user_updated_idx ON journal_entries (user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS resurfacing_events (
  id bigserial PRIMARY KEY,
  user_id text,
  subject_key text NOT NULL,
  event_name text NOT NULL,
  confidence_bucket text,
  phrase_key_hash text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS resurfacing_events_subject_created_idx ON resurfacing_events (subject_key, created_at DESC);

CREATE TABLE IF NOT EXISTS resurfacing_feedback (
  id bigserial PRIMARY KEY,
  user_id text NOT NULL,
  phrase_key_hash text NOT NULL,
  feedback_type text NOT NULL,
  feedback_weight integer NOT NULL,
  evidence_cluster_hash text,
  topic_hash text,
  person_hash text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS resurfacing_feedback_user_created_idx ON resurfacing_feedback (user_id, created_at DESC);
