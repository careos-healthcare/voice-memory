-- Content-free, server-authoritative usage reservations.
-- Runtime mirror: AUTH_SYNC_SCHEMA_STATEMENTS in lib/server/db.ts.

CREATE TABLE IF NOT EXISTS billing_entitlement_sources (
  user_id text NOT NULL,
  provider text NOT NULL CHECK (provider IN ('stripe', 'revenuecat')),
  status text NOT NULL
    CHECK (status IN ('active', 'trialing', 'inactive', 'expired', 'billing_issue')),
  plan_id text NOT NULL CHECK (plan_id ~ '^[A-Za-z][A-Za-z0-9_]{0,63}$'),
  period_start timestamptz,
  period_end timestamptz,
  lifetime boolean NOT NULL DEFAULT false,
  provider_event_timestamp timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider),
  CHECK (period_end IS NULL OR period_start IS NULL OR period_end > period_start)
);

CREATE INDEX IF NOT EXISTS billing_entitlement_sources_status_idx
  ON billing_entitlement_sources (provider, status, period_end);

CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
  event_id text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS usage_reservations (
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
  safe_result_code text CHECK (
    safe_result_code IS NULL OR safe_result_code ~ '^[a-z][a-z0-9_]{0,63}$'
  ),
  idempotency_key_hash text NOT NULL
    CHECK (idempotency_key_hash ~ '^[a-f0-9]{64}$'),
  status text NOT NULL CHECK (status IN ('reserved', 'committed', 'released')),
  expires_at timestamptz NOT NULL,
  committed_at timestamptz,
  released_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end > period_start),
  UNIQUE (user_id, meter_id, period_start, idempotency_key_hash)
);

ALTER TABLE usage_reservations
  ADD COLUMN IF NOT EXISTS units_released integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_input_units integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_output_units integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS audio_seconds integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS policy_version text NOT NULL DEFAULT 'legacy',
  ADD COLUMN IF NOT EXISTS safe_result_code text;

CREATE INDEX IF NOT EXISTS usage_reservations_allowance_idx
  ON usage_reservations
  (user_id, meter_id, period_start, status, expires_at);

-- reserveUsage serializes each user/meter/period with pg_advisory_xact_lock,
-- then sums committed and unexpired reservations in the same transaction.
