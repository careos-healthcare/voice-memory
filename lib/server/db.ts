import type { Pool, QueryResult, QueryResultRow } from "pg";
import { Pool as PgPool } from "pg";

/** Bundled schema — must not rely on docs/ at runtime (Vercel serverless omits it). */
export const AUTH_SYNC_SCHEMA_STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS auth_codes (
  email text PRIMARY KEY,
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS auth_codes_expires_at_idx ON auth_codes (expires_at)`,
  `CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL,
  email text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions (user_id)`,
  `CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions (expires_at)`,
  `CREATE TABLE IF NOT EXISTS user_profiles (
  user_id text PRIMARY KEY,
  focus_area text NOT NULL DEFAULT 'General',
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE TABLE IF NOT EXISTS sync_blobs (
  user_id text NOT NULL,
  blob_type text NOT NULL,
  blob_id text NOT NULL,
  encrypted_payload jsonb NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, blob_type, blob_id)
)`,
  `ALTER TABLE sync_blobs ADD COLUMN IF NOT EXISTS device_id text`,
  `ALTER TABLE sync_blobs ADD COLUMN IF NOT EXISTS vector_clock jsonb`,
  `ALTER TABLE sync_blobs ADD COLUMN IF NOT EXISTS key_epoch integer NOT NULL DEFAULT 1`,
  `CREATE INDEX IF NOT EXISTS sync_blobs_user_updated_idx ON sync_blobs (user_id, updated_at DESC)`,
  `CREATE INDEX IF NOT EXISTS sync_blobs_device_idx ON sync_blobs (user_id, device_id, updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS sync_recovery_envelopes (
  user_id text PRIMARY KEY,
  owner_archive_id text NOT NULL,
  key_epoch integer NOT NULL CHECK (key_epoch > 0),
  envelope_revision integer NOT NULL CHECK (envelope_revision > 0),
  envelope jsonb NOT NULL,
  envelope_digest text NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
)`,
  `CREATE INDEX IF NOT EXISTS sync_recovery_envelopes_updated_idx
   ON sync_recovery_envelopes (updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS api_usage (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  transcribe_count integer NOT NULL DEFAULT 0,
  analyze_count integer NOT NULL DEFAULT 0,
  atmosphere_count integer NOT NULL DEFAULT 0,
  attest_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
)`,
  `CREATE TABLE IF NOT EXISTS api_minute_usage (
  subject_key text NOT NULL,
  endpoint text NOT NULL,
  minute_key text NOT NULL,
  request_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, endpoint, minute_key)
)`,
  `CREATE TABLE IF NOT EXISTS openai_daily_spend (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  spend_micro_usd bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
)`,
  `CREATE TABLE IF NOT EXISTS billing_entitlements (
  user_id text PRIMARY KEY,
  stripe_customer_id text,
  stripe_subscription_id text,
  status text NOT NULL DEFAULT 'canceled',
  tier text NOT NULL DEFAULT 'free',
  billing_period_start timestamptz,
  subscription_end_date timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `ALTER TABLE billing_entitlements ADD COLUMN IF NOT EXISTS billing_period_start timestamptz`,
  `ALTER TABLE billing_entitlements ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz`,
  `CREATE TABLE IF NOT EXISTS revenuecat_user_mappings (
  user_id text PRIMARY KEY,
  app_user_id text NOT NULL UNIQUE,
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE TABLE IF NOT EXISTS billing_entitlement_sources (
  user_id text NOT NULL,
  provider text NOT NULL CHECK (provider IN ('stripe','revenuecat')),
  status text NOT NULL CHECK (status IN ('active','trialing','inactive','expired','billing_issue')),
  plan_id text NOT NULL CHECK (plan_id ~ '^[A-Za-z][A-Za-z0-9_]{0,63}$'),
  period_start timestamptz,
  period_end timestamptz,
  lifetime boolean NOT NULL DEFAULT false,
  provider_event_timestamp timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider),
  CHECK (period_end IS NULL OR period_start IS NULL OR period_end > period_start)
)`,
  `CREATE INDEX IF NOT EXISTS billing_entitlement_sources_status_idx
   ON billing_entitlement_sources (provider, status, period_end)`,
  `CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
  event_id text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE TABLE IF NOT EXISTS usage_reservations (
  reservation_id uuid PRIMARY KEY,
  user_id text NOT NULL,
  plan_id text NOT NULL CHECK (plan_id ~ '^[A-Za-z][A-Za-z0-9_]{0,63}$'),
  capability_id text NOT NULL,
  meter_id text NOT NULL,
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  units_reserved integer NOT NULL CHECK (units_reserved > 0),
  units_committed integer NOT NULL DEFAULT 0 CHECK (units_committed >= 0),
  units_released integer NOT NULL DEFAULT 0 CHECK (units_released >= 0),
  provider_input_units integer NOT NULL DEFAULT 0 CHECK (provider_input_units >= 0),
  provider_output_units integer NOT NULL DEFAULT 0 CHECK (provider_output_units >= 0),
  audio_seconds integer NOT NULL DEFAULT 0 CHECK (audio_seconds >= 0),
  policy_version text NOT NULL,
  safe_result_code text,
  idempotency_key_hash text NOT NULL CHECK (idempotency_key_hash ~ '^[a-f0-9]{64}$'),
  status text NOT NULL CHECK (status IN ('reserved','committed','released')),
  expires_at timestamptz NOT NULL,
  committed_at timestamptz,
  released_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end > period_start),
  UNIQUE (user_id, meter_id, period_start, idempotency_key_hash)
)`,
  `ALTER TABLE usage_reservations
   ADD COLUMN IF NOT EXISTS units_released integer NOT NULL DEFAULT 0,
   ADD COLUMN IF NOT EXISTS provider_input_units integer NOT NULL DEFAULT 0,
   ADD COLUMN IF NOT EXISTS provider_output_units integer NOT NULL DEFAULT 0,
   ADD COLUMN IF NOT EXISTS audio_seconds integer NOT NULL DEFAULT 0,
   ADD COLUMN IF NOT EXISTS policy_version text NOT NULL DEFAULT 'legacy',
   ADD COLUMN IF NOT EXISTS safe_result_code text`,
  `CREATE INDEX IF NOT EXISTS usage_reservations_allowance_idx
   ON usage_reservations (user_id, meter_id, period_start, status, expires_at)`,
  `CREATE TABLE IF NOT EXISTS capture_attestations (
  token_jti text PRIMARY KEY,
  device_id text NOT NULL,
  ip_hash text NOT NULL,
  ua_hash text NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  use_count integer NOT NULL DEFAULT 0,
  max_uses integer NOT NULL DEFAULT 500
)`,
  `CREATE TABLE IF NOT EXISTS journal_entries (
  user_id text NOT NULL,
  entry_id text NOT NULL,
  payload jsonb NOT NULL,
  sync_status text NOT NULL DEFAULT 'synced',
  client_updated_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entry_id)
)`,
  `CREATE INDEX IF NOT EXISTS journal_entries_user_updated_idx ON journal_entries (user_id, updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS resurfacing_events (
  id bigserial PRIMARY KEY,
  user_id text,
  subject_key text NOT NULL,
  event_name text NOT NULL,
  confidence_bucket text,
  phrase_key_hash text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS resurfacing_events_subject_created_idx ON resurfacing_events (subject_key, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS resurfacing_feedback (
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
)`,
  `CREATE INDEX IF NOT EXISTS resurfacing_feedback_user_created_idx ON resurfacing_feedback (user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS ai_accuracy_feedback (
  user_id text NOT NULL,
  conclusion_id text NOT NULL,
  engine text NOT NULL,
  confidence_percentage integer NOT NULL CHECK (confidence_percentage BETWEEN 0 AND 100),
  feedback_state text NOT NULL CHECK (feedback_state IN ('pending', 'correct', 'incorrect', 'later')),
  feedback_timestamp timestamptz NOT NULL,
  correction_note text,
  node_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  edge_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, conclusion_id)
)`,
  `ALTER TABLE ai_accuracy_feedback ADD COLUMN IF NOT EXISTS edge_ids jsonb NOT NULL DEFAULT '[]'::jsonb`,
  `ALTER TABLE ai_accuracy_feedback DROP CONSTRAINT IF EXISTS ai_accuracy_feedback_feedback_state_check`,
  `UPDATE ai_accuracy_feedback SET feedback_state = 'later' WHERE feedback_state = 'deferred'`,
  `DO $$ BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'ai_accuracy_feedback_feedback_state_check'
    ) THEN
      ALTER TABLE ai_accuracy_feedback
        ADD CONSTRAINT ai_accuracy_feedback_feedback_state_check
        CHECK (feedback_state IN ('pending', 'correct', 'incorrect', 'later'));
    END IF;
  END $$`,
  `CREATE INDEX IF NOT EXISTS ai_accuracy_feedback_user_updated_idx ON ai_accuracy_feedback (user_id, updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  event_id text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
)`,
  `ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS atmosphere_count integer NOT NULL DEFAULT 0`,
  `ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS attest_count integer NOT NULL DEFAULT 0`,
  `ALTER TABLE auth_codes ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0`,
  `CREATE TABLE IF NOT EXISTS mobile_push_devices (
  user_id text NOT NULL,
  device_id text PRIMARY KEY,
  platform text NOT NULL,
  fcm_token text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS mobile_push_devices_user_id_idx ON mobile_push_devices (user_id)`,
  `CREATE INDEX IF NOT EXISTS mobile_push_devices_updated_at_idx ON mobile_push_devices (updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS account_deletion_requests (
  request_id text PRIMARY KEY,
  user_id text NOT NULL UNIQUE,
  normalized_email text NOT NULL,
  economics_subject_keys text[] NOT NULL DEFAULT '{}',
  status text NOT NULL CHECK (status IN ('pending', 'processing', 'blocked')),
  registry_version integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `ALTER TABLE account_deletion_requests
   ADD COLUMN IF NOT EXISTS economics_subject_keys text[] NOT NULL DEFAULT '{}'`,
  `CREATE INDEX IF NOT EXISTS account_deletion_requests_status_updated_idx
   ON account_deletion_requests (status, updated_at)`,
  `CREATE TABLE IF NOT EXISTS account_deletion_outbox (
  job_id text PRIMARY KEY,
  request_id text NOT NULL REFERENCES account_deletion_requests(request_id) ON DELETE CASCADE,
  processor text NOT NULL CHECK (processor IN ('stripe-customer', 'revenuecat-subscriber')),
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'retry', 'complete', 'blocked')),
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (request_id, processor)
)`,
  `CREATE INDEX IF NOT EXISTS account_deletion_outbox_retry_idx
   ON account_deletion_outbox (status, next_attempt_at)`,
  `CREATE TABLE IF NOT EXISTS account_deletion_receipts (
  receipt_id text PRIMARY KEY,
  registry_version integer NOT NULL,
  outcome text NOT NULL CHECK (outcome = 'complete'),
  completed_at timestamptz NOT NULL DEFAULT now()
)`,
] as const;

/** Unit economics migration mirror — docs/sql/004_unit_economics.sql is not available at runtime. */
export const UNIT_ECONOMICS_SCHEMA_STATEMENTS = [
  `CREATE OR REPLACE FUNCTION ue_dimensions_are_safe(value jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
    SELECT jsonb_typeof(value) = 'object'
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_object_keys(value) AS item(key_name)
        WHERE key_name NOT IN ('provider', 'model', 'region', 'plan', 'platform')
      )
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_each_text(value) AS item(key_name, value_text)
        WHERE jsonb_typeof(value -> key_name) IS DISTINCT FROM 'string'
           OR (key_name = 'provider' AND value_text NOT IN ('openai', 'google', 'stripe', 'revenuecat', 'aws', 'cloudflare', 'internal', 'other'))
           OR (key_name = 'model' AND value_text NOT IN ('gpt-4o-mini', 'gpt-5', 'gpt-5.5', 'gpt-5.5-pro', 'whisper-1', 'gemini-live', 'other'))
           OR (key_name = 'region' AND value_text NOT IN ('us', 'eu', 'global', 'other'))
           OR (key_name = 'plan' AND value_text NOT IN ('free', 'pro', 'trial', 'other'))
           OR (key_name = 'platform' AND value_text NOT IN ('web', 'ios', 'android', 'server', 'other'))
      )
  $$`,
  `CREATE TABLE IF NOT EXISTS ue_pricing_versions (
    version_key text PRIMARY KEY, effective_from timestamptz NOT NULL, effective_to timestamptz,
    currency text NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'), created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (version_key ~ '^[a-zA-Z0-9._:-]{1,64}$'), CHECK (effective_to IS NULL OR effective_to > effective_from)
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS ue_pricing_versions_effective_from_idx ON ue_pricing_versions (effective_from)`,
  `CREATE TABLE IF NOT EXISTS ue_price_lines (
    version_key text NOT NULL REFERENCES ue_pricing_versions(version_key), metric text NOT NULL,
    resource text NOT NULL, cogs_category text NOT NULL, unit_quantity bigint NOT NULL CHECK (unit_quantity > 0),
    unit_price_micro_usd bigint NOT NULL CHECK (unit_price_micro_usd >= 0),
    cost_basis text NOT NULL CHECK (cost_basis IN ('exact', 'estimated')), created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (version_key, metric, resource),
    CHECK (cogs_category IN ('ai', 'transcription', 'storage', 'bandwidth', 'live', 'image')),
    CHECK (resource IN ('openai.gpt-4o-mini','openai.gpt-5','openai.gpt-5.5','openai.gpt-5.5-pro','openai.whisper-1','google.gemini-live','storage.snapshot','network.ingress','network.egress','network.retrieval','image.atmosphere','stripe.subscription','revenuecat.subscription','credit.subscription','adjustment.correction')),
    CHECK (
      (metric IN ('ai_input_tokens','ai_output_tokens','ai_cached_tokens','ai_reasoning_tokens') AND resource IN ('openai.gpt-4o-mini','openai.gpt-5','openai.gpt-5.5','openai.gpt-5.5-pro'))
      OR (metric = 'transcription_audio_milliseconds' AND resource = 'openai.whisper-1')
      OR (metric = 'storage_snapshot_bytes' AND resource = 'storage.snapshot')
      OR (metric = 'ingress_bytes' AND resource = 'network.ingress')
      OR (metric = 'egress_bytes' AND resource = 'network.egress')
      OR (metric = 'retrieval_bytes' AND resource = 'network.retrieval')
      OR (metric = 'live_session_milliseconds' AND resource = 'google.gemini-live')
      OR (metric = 'image_generations' AND resource = 'image.atmosphere')
    )
  )`,
  `CREATE TABLE IF NOT EXISTS ue_usage_ledger (
    event_key text PRIMARY KEY, subject_key text NOT NULL, subject_key_version integer NOT NULL CHECK (subject_key_version > 0),
    metric text NOT NULL, resource text NOT NULL, quantity bigint NOT NULL, category text NOT NULL,
    exact_cost_micro_usd bigint NOT NULL DEFAULT 0, estimated_cost_micro_usd bigint NOT NULL DEFAULT 0,
    measurement_basis text NOT NULL CHECK (measurement_basis IN ('exact', 'estimated')),
    pricing_version_key text REFERENCES ue_pricing_versions(version_key), dimensions jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL, day date NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
    CHECK (event_key ~ '^uee:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
    CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
    CHECK (metric IN ('ai_input_tokens','ai_output_tokens','ai_cached_tokens','ai_reasoning_tokens','transcription_audio_milliseconds','storage_snapshot_bytes','ingress_bytes','egress_bytes','retrieval_bytes','live_session_milliseconds','image_generations','revenue','credits','adjustments')),
    CHECK (category IN ('ai','transcription','storage','bandwidth','live','image','revenue','credits','adjustments')),
    CHECK (
      (metric IN ('ai_input_tokens','ai_output_tokens','ai_cached_tokens','ai_reasoning_tokens') AND category = 'ai')
      OR (metric = 'transcription_audio_milliseconds' AND category = 'transcription')
      OR (metric = 'storage_snapshot_bytes' AND category = 'storage')
      OR (metric IN ('ingress_bytes','egress_bytes','retrieval_bytes') AND category = 'bandwidth')
      OR (metric = 'live_session_milliseconds' AND category = 'live')
      OR (metric = 'image_generations' AND category = 'image')
      OR (metric = 'revenue' AND category = 'revenue')
      OR (metric = 'credits' AND category = 'credits')
      OR (metric = 'adjustments' AND category = 'adjustments')
    ),
    CHECK (quantity >= 0 OR metric = 'adjustments'),
    CHECK (metric = 'adjustments' OR (exact_cost_micro_usd >= 0 AND estimated_cost_micro_usd >= 0)),
    CHECK (exact_cost_micro_usd = 0 OR estimated_cost_micro_usd = 0),
    CHECK (day = (occurred_at AT TIME ZONE 'UTC')::date), CHECK (ue_dimensions_are_safe(dimensions)),
    CHECK (resource IN ('openai.gpt-4o-mini','openai.gpt-5','openai.gpt-5.5','openai.gpt-5.5-pro','openai.whisper-1','google.gemini-live','storage.snapshot','network.ingress','network.egress','network.retrieval','image.atmosphere','stripe.subscription','revenuecat.subscription','credit.subscription','adjustment.correction')),
    CHECK (
      (metric IN ('ai_input_tokens','ai_output_tokens','ai_cached_tokens','ai_reasoning_tokens') AND resource IN ('openai.gpt-4o-mini','openai.gpt-5','openai.gpt-5.5','openai.gpt-5.5-pro'))
      OR (metric = 'transcription_audio_milliseconds' AND resource = 'openai.whisper-1')
      OR (metric = 'storage_snapshot_bytes' AND resource = 'storage.snapshot')
      OR (metric = 'ingress_bytes' AND resource = 'network.ingress')
      OR (metric = 'egress_bytes' AND resource = 'network.egress')
      OR (metric = 'retrieval_bytes' AND resource = 'network.retrieval')
      OR (metric = 'live_session_milliseconds' AND resource = 'google.gemini-live')
      OR (metric = 'image_generations' AND resource = 'image.atmosphere')
      OR (metric = 'revenue' AND resource IN ('stripe.subscription','revenuecat.subscription'))
      OR (metric = 'credits' AND resource = 'credit.subscription')
      OR (metric = 'adjustments' AND resource = 'adjustment.correction')
    )
  )`,
  `ALTER TABLE ue_usage_ledger ADD COLUMN IF NOT EXISTS measurement_basis text NOT NULL DEFAULT 'estimated'`,
  `DO $$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'ue_usage_ledger_measurement_basis_check'
        AND conrelid = 'ue_usage_ledger'::regclass
    ) THEN
      ALTER TABLE ue_usage_ledger
        ADD CONSTRAINT ue_usage_ledger_measurement_basis_check
        CHECK (measurement_basis IN ('exact', 'estimated'));
    END IF;
  END;
  $$`,
  `CREATE INDEX IF NOT EXISTS ue_usage_ledger_subject_day_idx ON ue_usage_ledger (subject_key, day)`,
  `CREATE INDEX IF NOT EXISTS ue_usage_ledger_day_category_idx ON ue_usage_ledger (day, category)`,
  `CREATE INDEX IF NOT EXISTS ue_usage_ledger_day_subject_idx ON ue_usage_ledger (day, subject_key)`,
  `CREATE TABLE IF NOT EXISTS ue_daily_subject_rollups (
    subject_key text NOT NULL, subject_key_version integer NOT NULL CHECK (subject_key_version > 0), day date NOT NULL,
    revenue_micro_usd bigint NOT NULL DEFAULT 0, credits_micro_usd bigint NOT NULL DEFAULT 0,
    adjustments_micro_usd bigint NOT NULL DEFAULT 0, ai_cogs_micro_usd bigint NOT NULL DEFAULT 0,
    transcription_cogs_micro_usd bigint NOT NULL DEFAULT 0, storage_cogs_micro_usd bigint NOT NULL DEFAULT 0,
    bandwidth_cogs_micro_usd bigint NOT NULL DEFAULT 0, live_cogs_micro_usd bigint NOT NULL DEFAULT 0,
    image_cogs_micro_usd bigint NOT NULL DEFAULT 0, total_cogs_micro_usd bigint NOT NULL DEFAULT 0,
    contribution_margin_micro_usd bigint NOT NULL DEFAULT 0, margin_bps integer,
    reconciled_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (subject_key, day),
    CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$')
  )`,
  `CREATE INDEX IF NOT EXISTS ue_daily_subject_rollups_day_idx ON ue_daily_subject_rollups (day)`,
  `CREATE TABLE IF NOT EXISTS ue_threshold_breaches (
    breach_key text PRIMARY KEY, dedup_key text NOT NULL UNIQUE, subject_key text NOT NULL,
    subject_key_version integer NOT NULL CHECK (subject_key_version > 0), day date NOT NULL,
    threshold_code text NOT NULL, status text NOT NULL CHECK (status IN ('open', 'acknowledged', 'resolved')),
    observed_value bigint NOT NULL, threshold_value bigint NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (breach_key ~ '^ueb:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
    CHECK (dedup_key ~ '^ued:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
    CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
    CHECK (threshold_code IN ('negative_margin', 'low_margin_bps', 'high_daily_cogs', 'absolute_loss'))
  )`,
  `CREATE INDEX IF NOT EXISTS ue_threshold_breaches_subject_day_idx ON ue_threshold_breaches (subject_key, day)`,
  `CREATE OR REPLACE FUNCTION ue_reject_source_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF current_setting('voicememory.account_deletion', true) = 'on' THEN
        RETURN OLD;
      END IF;
      RAISE EXCEPTION 'unit economics source rows are append-only; insert a compensating row';
    END;
  $$`,
  `DROP TRIGGER IF EXISTS ue_pricing_versions_immutable ON ue_pricing_versions`,
  `CREATE TRIGGER ue_pricing_versions_immutable BEFORE UPDATE OR DELETE ON ue_pricing_versions FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation()`,
  `DROP TRIGGER IF EXISTS ue_price_lines_immutable ON ue_price_lines`,
  `CREATE TRIGGER ue_price_lines_immutable BEFORE UPDATE OR DELETE ON ue_price_lines FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation()`,
  `DROP TRIGGER IF EXISTS ue_usage_ledger_immutable ON ue_usage_ledger`,
  `CREATE TRIGGER ue_usage_ledger_immutable BEFORE UPDATE OR DELETE ON ue_usage_ledger FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation()`,
  `DROP TRIGGER IF EXISTS ue_threshold_breaches_immutable ON ue_threshold_breaches`,
  `CREATE TRIGGER ue_threshold_breaches_immutable BEFORE UPDATE OR DELETE ON ue_threshold_breaches FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation()`,
  `CREATE OR REPLACE FUNCTION delete_user_unit_economics(subject_keys text[])
   RETURNS integer LANGUAGE plpgsql SECURITY INVOKER AS $$
   DECLARE removed integer := 0; affected integer := 0;
   BEGIN
     PERFORM set_config('voicememory.account_deletion', 'on', true);
     DELETE FROM ue_threshold_breaches WHERE subject_key = ANY(subject_keys);
     GET DIAGNOSTICS affected = ROW_COUNT; removed := removed + affected;
     DELETE FROM ue_daily_subject_rollups WHERE subject_key = ANY(subject_keys);
     GET DIAGNOSTICS affected = ROW_COUNT; removed := removed + affected;
     DELETE FROM ue_usage_ledger WHERE subject_key = ANY(subject_keys);
     GET DIAGNOSTICS affected = ROW_COUNT; removed := removed + affected;
     RETURN removed;
   END;
   $$`,
] as const;

const ACCOUNT_DELETION_WRITE_GUARD_TARGETS = [
  ["auth_codes", "email", "email"],
  ["sessions", "user_id", "user_id"],
  ["user_profiles", "user_id", "user_id"],
  ["sync_blobs", "user_id", "user_id"],
  ["sync_recovery_envelopes", "user_id", "user_id"],
  ["api_usage", "subject_key", "subject_key"],
  ["api_minute_usage", "subject_key", "subject_key"],
  ["openai_daily_spend", "subject_key", "subject_key"],
  ["billing_entitlements", "user_id", "user_id"],
  ["revenuecat_user_mappings", "user_id", "user_id"],
  ["billing_entitlement_sources", "user_id", "user_id"],
  ["usage_reservations", "user_id", "user_id"],
  ["journal_entries", "user_id", "user_id"],
  ["resurfacing_events", "user_id", "user_id"],
  ["resurfacing_events", "subject_key", "subject_key"],
  ["resurfacing_feedback", "user_id", "user_id"],
  ["ai_accuracy_feedback", "user_id", "user_id"],
  ["mobile_push_devices", "user_id", "user_id"],
  ["ue_usage_ledger", "subject_key", "subject_key"],
  ["ue_daily_subject_rollups", "subject_key", "subject_key"],
  ["ue_threshold_breaches", "subject_key", "subject_key"],
] as const;

export const ACCOUNT_DELETION_WRITE_GUARD_STATEMENTS = [
  `CREATE OR REPLACE FUNCTION block_writes_during_account_deletion()
   RETURNS trigger LANGUAGE plpgsql AS $$
   DECLARE candidate text := to_jsonb(NEW) ->> TG_ARGV[0];
   BEGIN
     IF current_setting('voicememory.account_deletion', true) = 'on' THEN RETURN NEW; END IF;
     IF candidate IS NULL THEN RETURN NEW; END IF;
     IF (TG_ARGV[1] = 'user_id' AND EXISTS (
           SELECT 1 FROM account_deletion_requests WHERE user_id = candidate
         ))
        OR (TG_ARGV[1] = 'email' AND EXISTS (
           SELECT 1 FROM account_deletion_requests WHERE normalized_email = lower(candidate)
         ))
        OR (TG_ARGV[1] = 'subject_key' AND EXISTS (
           SELECT 1 FROM account_deletion_requests
           WHERE candidate = 'user:' || user_id
              OR candidate = ANY(economics_subject_keys)
         ))
     THEN
       RAISE EXCEPTION 'ACCOUNT_DELETION_PENDING' USING ERRCODE = '55000';
     END IF;
     RETURN NEW;
   END;
   $$`,
  ...ACCOUNT_DELETION_WRITE_GUARD_TARGETS.flatMap(([table, column, strategy]) => [
    `DROP TRIGGER IF EXISTS ${table}_${column}_account_deletion_guard ON ${table}`,
    `CREATE TRIGGER ${table}_${column}_account_deletion_guard
     BEFORE INSERT OR UPDATE ON ${table}
     FOR EACH ROW EXECUTE FUNCTION block_writes_during_account_deletion('${column}', '${strategy}')`,
  ]),
] as const;

export const DATABASE_SCHEMA_STATEMENTS = [
  ...AUTH_SYNC_SCHEMA_STATEMENTS,
  ...UNIT_ECONOMICS_SCHEMA_STATEMENTS,
  ...ACCOUNT_DELETION_WRITE_GUARD_STATEMENTS,
] as const;

let lastConnectionError: string | null = null;

function logDbError(scope: string, error: unknown, extra: Record<string, unknown> = {}): void {
  const err = error instanceof Error ? error : new Error(String(error));
  console.error(
    "[ArchiveMe auth]",
    JSON.stringify({
      route: scope,
      message: err.message,
      stack: err.stack ?? null,
      poolInitialized: pool !== null,
      databaseUrlPresent: hasDatabaseUrl(),
      ...extra,
    }),
  );
}

let pool: Pool | null = null;
let schemaReady: Promise<void> | null = null;

export function hasDatabaseUrl(): boolean {
  return Boolean(process.env.DATABASE_URL?.trim());
}

export function shouldUsePostgresStorage(): boolean {
  return hasDatabaseUrl();
}

export function isProductionRuntime(): boolean {
  return process.env.NODE_ENV === "production";
}

/** Production must not fall back to local filesystem when DATABASE_URL is set. */
export function shouldUseFilesystemStorage(): boolean {
  if (shouldUsePostgresStorage()) return false;
  return !isProductionRuntime();
}

function resolvePoolSsl(connectionString: string): boolean | { rejectUnauthorized: boolean } | undefined {
  const lower = connectionString.toLowerCase();
  if (lower.includes("sslmode=disable") || lower.includes("ssl=false")) {
    return undefined;
  }
  if (lower.includes("sslmode=require") || lower.includes("sslmode=verify-full")) {
    return { rejectUnauthorized: false };
  }
  if (
    lower.includes("neon.tech") ||
    lower.includes("supabase.co") ||
    lower.includes("pooler.supabase") ||
    lower.includes("vercel-storage.com") ||
    isProductionRuntime()
  ) {
    return { rejectUnauthorized: false };
  }
  return undefined;
}

export function isDatabasePoolInitialized(): boolean {
  return pool !== null;
}

export function getDatabaseDiagnostics(): {
  poolInitialized: boolean;
  schemaReadyPending: boolean;
  lastConnectionError: string | null;
} {
  return {
    poolInitialized: pool !== null,
    schemaReadyPending: schemaReady !== null,
    lastConnectionError,
  };
}

export function getDatabasePool(): Pool {
  if (!hasDatabaseUrl()) {
    throw new Error("DATABASE_URL is not configured.");
  }

  if (!pool) {
    const connectionString = process.env.DATABASE_URL!.trim();
    pool = new PgPool({
      connectionString,
      max: 5,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: 10_000,
      ssl: resolvePoolSsl(connectionString),
    });
    pool.on("error", (error) => {
      lastConnectionError = error.message;
      logDbError("db/pool", error, { event: "idle_client_error" });
    });
  }

  return pool;
}

async function runSchemaStatements(client: Pool): Promise<void> {
  for (const statement of DATABASE_SCHEMA_STATEMENTS) {
    await client.query(statement);
  }
}

/** Idempotent table setup — safe on cold starts. */
export async function ensureDatabaseSchema(): Promise<void> {
  if (!hasDatabaseUrl()) return;
  if (!schemaReady) {
    schemaReady = runSchemaStatements(getDatabasePool())
      .then(() => {
        lastConnectionError = null;
      })
      .catch((error) => {
        schemaReady = null;
        lastConnectionError = error instanceof Error ? error.message : String(error);
        logDbError("db/schema", error, { statements: DATABASE_SCHEMA_STATEMENTS.length });
        throw error;
      });
  }
  await schemaReady;
}

export async function dbQuery<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: unknown[] = [],
): Promise<QueryResult<T>> {
  try {
    await ensureDatabaseSchema();
    return await getDatabasePool().query<T>(text, params);
  } catch (error) {
    lastConnectionError = error instanceof Error ? error.message : String(error);
    logDbError("db/query", error, { queryPrefix: text.slice(0, 48) });
    throw error;
  }
}

export async function closeDatabasePool(): Promise<void> {
  if (!pool) return;
  await pool.end();
  pool = null;
  schemaReady = null;
}
