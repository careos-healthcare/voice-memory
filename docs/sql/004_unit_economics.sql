-- Privacy-safe unit economics infrastructure.
-- Runtime bootstrap mirrors every statement in lib/server/db.ts.

CREATE OR REPLACE FUNCTION ue_dimensions_are_safe(value jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_typeof(value) = 'object'
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_object_keys(value) AS item(key_name)
      WHERE key_name NOT IN ('provider', 'model', 'region', 'plan', 'platform')
    )
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_each_text(value) AS item(key_name, value_text)
      WHERE jsonb_typeof(value -> key_name) IS DISTINCT FROM 'string'
         OR (key_name = 'provider' AND value_text NOT IN ('openai', 'google', 'stripe', 'revenuecat', 'aws', 'cloudflare', 'internal', 'other'))
         OR (key_name = 'model' AND value_text NOT IN ('gpt-4o-mini', 'gpt-5', 'gpt-5.5', 'gpt-5.5-pro', 'whisper-1', 'gemini-live', 'other'))
         OR (key_name = 'region' AND value_text NOT IN ('us', 'eu', 'global', 'other'))
         OR (key_name = 'plan' AND value_text NOT IN ('free', 'pro', 'trial', 'other'))
         OR (key_name = 'platform' AND value_text NOT IN ('web', 'ios', 'android', 'server', 'other'))
    )
$$;

CREATE TABLE IF NOT EXISTS ue_pricing_versions (
  version_key text PRIMARY KEY,
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  currency text NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (version_key ~ '^[a-zA-Z0-9._:-]{1,64}$'),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS ue_pricing_versions_effective_from_idx
  ON ue_pricing_versions (effective_from);

CREATE TABLE IF NOT EXISTS ue_price_lines (
  version_key text NOT NULL REFERENCES ue_pricing_versions(version_key),
  metric text NOT NULL,
  resource text NOT NULL,
  cogs_category text NOT NULL,
  unit_quantity bigint NOT NULL CHECK (unit_quantity > 0),
  unit_price_micro_usd bigint NOT NULL CHECK (unit_price_micro_usd >= 0),
  cost_basis text NOT NULL CHECK (cost_basis IN ('exact', 'estimated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (version_key, metric, resource),
  CHECK (cogs_category IN ('ai', 'transcription', 'storage', 'bandwidth', 'live', 'image')),
  CHECK (resource IN (
    'openai.gpt-4o-mini', 'openai.gpt-5', 'openai.gpt-5.5', 'openai.gpt-5.5-pro',
    'openai.whisper-1', 'google.gemini-live',
    'storage.snapshot', 'network.ingress', 'network.egress', 'network.retrieval',
    'image.atmosphere', 'stripe.subscription', 'revenuecat.subscription',
    'credit.subscription', 'adjustment.correction'
  )),
  CHECK (
    (metric IN ('ai_input_tokens', 'ai_output_tokens', 'ai_cached_tokens', 'ai_reasoning_tokens')
      AND resource IN ('openai.gpt-4o-mini', 'openai.gpt-5', 'openai.gpt-5.5', 'openai.gpt-5.5-pro'))
    OR (metric = 'transcription_audio_milliseconds' AND resource = 'openai.whisper-1')
    OR (metric = 'storage_snapshot_bytes' AND resource = 'storage.snapshot')
    OR (metric = 'ingress_bytes' AND resource = 'network.ingress')
    OR (metric = 'egress_bytes' AND resource = 'network.egress')
    OR (metric = 'retrieval_bytes' AND resource = 'network.retrieval')
    OR (metric = 'live_session_milliseconds' AND resource = 'google.gemini-live')
    OR (metric = 'image_generations' AND resource = 'image.atmosphere')
  )
);

CREATE TABLE IF NOT EXISTS ue_usage_ledger (
  event_key text PRIMARY KEY,
  subject_key text NOT NULL,
  subject_key_version integer NOT NULL CHECK (subject_key_version > 0),
  metric text NOT NULL,
  resource text NOT NULL,
  quantity bigint NOT NULL,
  category text NOT NULL,
  exact_cost_micro_usd bigint NOT NULL DEFAULT 0,
  estimated_cost_micro_usd bigint NOT NULL DEFAULT 0,
  measurement_basis text NOT NULL CHECK (measurement_basis IN ('exact', 'estimated')),
  pricing_version_key text REFERENCES ue_pricing_versions(version_key),
  dimensions jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL,
  day date NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CHECK (event_key ~ '^uee:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
  CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
  CHECK (metric IN (
    'ai_input_tokens', 'ai_output_tokens', 'ai_cached_tokens', 'ai_reasoning_tokens',
    'transcription_audio_milliseconds', 'storage_snapshot_bytes', 'ingress_bytes',
    'egress_bytes', 'retrieval_bytes', 'live_session_milliseconds',
    'image_generations', 'revenue', 'credits', 'adjustments'
  )),
  CHECK (category IN ('ai', 'transcription', 'storage', 'bandwidth', 'live', 'image', 'revenue', 'credits', 'adjustments')),
  CHECK (
    (metric IN ('ai_input_tokens', 'ai_output_tokens', 'ai_cached_tokens', 'ai_reasoning_tokens') AND category = 'ai')
    OR (metric = 'transcription_audio_milliseconds' AND category = 'transcription')
    OR (metric = 'storage_snapshot_bytes' AND category = 'storage')
    OR (metric IN ('ingress_bytes', 'egress_bytes', 'retrieval_bytes') AND category = 'bandwidth')
    OR (metric = 'live_session_milliseconds' AND category = 'live')
    OR (metric = 'image_generations' AND category = 'image')
    OR (metric = 'revenue' AND category = 'revenue')
    OR (metric = 'credits' AND category = 'credits')
    OR (metric = 'adjustments' AND category = 'adjustments')
  ),
  CHECK (quantity >= 0 OR metric = 'adjustments'),
  CHECK (
    (metric = 'adjustments')
    OR (exact_cost_micro_usd >= 0 AND estimated_cost_micro_usd >= 0)
  ),
  CHECK (exact_cost_micro_usd = 0 OR estimated_cost_micro_usd = 0),
  CHECK (day = (occurred_at AT TIME ZONE 'UTC')::date),
  CHECK (ue_dimensions_are_safe(dimensions)),
  CHECK (resource IN (
    'openai.gpt-4o-mini', 'openai.gpt-5', 'openai.gpt-5.5', 'openai.gpt-5.5-pro',
    'openai.whisper-1', 'google.gemini-live',
    'storage.snapshot', 'network.ingress', 'network.egress', 'network.retrieval',
    'image.atmosphere', 'stripe.subscription', 'revenuecat.subscription',
    'credit.subscription', 'adjustment.correction'
  )),
  CHECK (
    (metric IN ('ai_input_tokens', 'ai_output_tokens', 'ai_cached_tokens', 'ai_reasoning_tokens')
      AND resource IN ('openai.gpt-4o-mini', 'openai.gpt-5', 'openai.gpt-5.5', 'openai.gpt-5.5-pro'))
    OR (metric = 'transcription_audio_milliseconds' AND resource = 'openai.whisper-1')
    OR (metric = 'storage_snapshot_bytes' AND resource = 'storage.snapshot')
    OR (metric = 'ingress_bytes' AND resource = 'network.ingress')
    OR (metric = 'egress_bytes' AND resource = 'network.egress')
    OR (metric = 'retrieval_bytes' AND resource = 'network.retrieval')
    OR (metric = 'live_session_milliseconds' AND resource = 'google.gemini-live')
    OR (metric = 'image_generations' AND resource = 'image.atmosphere')
    OR (metric = 'revenue' AND resource IN ('stripe.subscription', 'revenuecat.subscription'))
    OR (metric = 'credits' AND resource = 'credit.subscription')
    OR (metric = 'adjustments' AND resource = 'adjustment.correction')
  )
);

ALTER TABLE ue_usage_ledger
  ADD COLUMN IF NOT EXISTS measurement_basis text NOT NULL DEFAULT 'estimated';

DO $$
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
$$;

CREATE INDEX IF NOT EXISTS ue_usage_ledger_subject_day_idx
  ON ue_usage_ledger (subject_key, day);
CREATE INDEX IF NOT EXISTS ue_usage_ledger_day_category_idx
  ON ue_usage_ledger (day, category);
CREATE INDEX IF NOT EXISTS ue_usage_ledger_day_subject_idx
  ON ue_usage_ledger (day, subject_key);

CREATE TABLE IF NOT EXISTS ue_daily_subject_rollups (
  subject_key text NOT NULL,
  subject_key_version integer NOT NULL CHECK (subject_key_version > 0),
  day date NOT NULL,
  revenue_micro_usd bigint NOT NULL DEFAULT 0,
  credits_micro_usd bigint NOT NULL DEFAULT 0,
  adjustments_micro_usd bigint NOT NULL DEFAULT 0,
  ai_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  transcription_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  storage_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  bandwidth_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  live_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  image_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  total_cogs_micro_usd bigint NOT NULL DEFAULT 0,
  contribution_margin_micro_usd bigint NOT NULL DEFAULT 0,
  margin_bps integer,
  reconciled_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (subject_key, day),
  CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$')
);

CREATE INDEX IF NOT EXISTS ue_daily_subject_rollups_day_idx
  ON ue_daily_subject_rollups (day);

CREATE TABLE IF NOT EXISTS ue_threshold_breaches (
  breach_key text PRIMARY KEY,
  dedup_key text NOT NULL UNIQUE,
  subject_key text NOT NULL,
  subject_key_version integer NOT NULL CHECK (subject_key_version > 0),
  day date NOT NULL,
  threshold_code text NOT NULL,
  status text NOT NULL CHECK (status IN ('open', 'acknowledged', 'resolved')),
  observed_value bigint NOT NULL,
  threshold_value bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (breach_key ~ '^ueb:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
  CHECK (dedup_key ~ '^ued:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
  CHECK (subject_key ~ '^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$'),
  CHECK (threshold_code IN ('negative_margin', 'low_margin_bps', 'high_daily_cogs', 'absolute_loss'))
);

CREATE INDEX IF NOT EXISTS ue_threshold_breaches_subject_day_idx
  ON ue_threshold_breaches (subject_key, day);

CREATE OR REPLACE FUNCTION ue_reject_source_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'unit economics source rows are append-only; insert a compensating row';
END;
$$;

DROP TRIGGER IF EXISTS ue_pricing_versions_immutable ON ue_pricing_versions;
CREATE TRIGGER ue_pricing_versions_immutable
BEFORE UPDATE OR DELETE ON ue_pricing_versions
FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation();

DROP TRIGGER IF EXISTS ue_price_lines_immutable ON ue_price_lines;
CREATE TRIGGER ue_price_lines_immutable
BEFORE UPDATE OR DELETE ON ue_price_lines
FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation();

DROP TRIGGER IF EXISTS ue_usage_ledger_immutable ON ue_usage_ledger;
CREATE TRIGGER ue_usage_ledger_immutable
BEFORE UPDATE OR DELETE ON ue_usage_ledger
FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation();

DROP TRIGGER IF EXISTS ue_threshold_breaches_immutable ON ue_threshold_breaches;
CREATE TRIGGER ue_threshold_breaches_immutable
BEFORE UPDATE OR DELETE ON ue_threshold_breaches
FOR EACH ROW EXECUTE FUNCTION ue_reject_source_mutation();
