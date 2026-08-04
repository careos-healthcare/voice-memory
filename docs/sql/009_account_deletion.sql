-- Durable, idempotent account-deletion state and provider retry outbox.

CREATE TABLE IF NOT EXISTS account_deletion_requests (
  request_id text PRIMARY KEY,
  user_id text NOT NULL UNIQUE,
  normalized_email text NOT NULL,
  economics_subject_keys text[] NOT NULL DEFAULT '{}',
  status text NOT NULL CHECK (status IN ('pending', 'processing', 'blocked')),
  registry_version integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE account_deletion_requests
  ADD COLUMN IF NOT EXISTS economics_subject_keys text[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS account_deletion_requests_status_updated_idx
  ON account_deletion_requests (status, updated_at);

CREATE TABLE IF NOT EXISTS account_deletion_outbox (
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
);

CREATE INDEX IF NOT EXISTS account_deletion_outbox_retry_idx
  ON account_deletion_outbox (status, next_attempt_at);

CREATE TABLE IF NOT EXISTS account_deletion_receipts (
  receipt_id text PRIMARY KEY,
  registry_version integer NOT NULL,
  outcome text NOT NULL CHECK (outcome = 'complete'),
  completed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION ue_reject_source_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('voicememory.account_deletion', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'unit economics source rows are append-only; insert a compensating row';
END;
$$;

CREATE OR REPLACE FUNCTION delete_user_unit_economics(subject_keys text[])
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
$$;

CREATE OR REPLACE FUNCTION block_writes_during_account_deletion()
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
        WHERE candidate = 'user:' || user_id OR candidate = ANY(economics_subject_keys)
      ))
  THEN
    RAISE EXCEPTION 'ACCOUNT_DELETION_PENDING' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE target record;
BEGIN
  FOR target IN SELECT * FROM (VALUES
    ('auth_codes', 'email', 'email'),
    ('sessions', 'user_id', 'user_id'),
    ('user_profiles', 'user_id', 'user_id'),
    ('sync_blobs', 'user_id', 'user_id'),
    ('api_usage', 'subject_key', 'subject_key'),
    ('api_minute_usage', 'subject_key', 'subject_key'),
    ('openai_daily_spend', 'subject_key', 'subject_key'),
    ('billing_entitlements', 'user_id', 'user_id'),
    ('revenuecat_user_mappings', 'user_id', 'user_id'),
    ('journal_entries', 'user_id', 'user_id'),
    ('resurfacing_events', 'user_id', 'user_id'),
    ('resurfacing_events', 'subject_key', 'subject_key'),
    ('resurfacing_feedback', 'user_id', 'user_id'),
    ('ai_accuracy_feedback', 'user_id', 'user_id'),
    ('mobile_push_devices', 'user_id', 'user_id'),
    ('ue_usage_ledger', 'subject_key', 'subject_key'),
    ('ue_daily_subject_rollups', 'subject_key', 'subject_key'),
    ('ue_threshold_breaches', 'subject_key', 'subject_key')
  ) AS targets(table_name, column_name, strategy)
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I',
      target.table_name || '_' || target.column_name || '_account_deletion_guard',
      target.table_name);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION block_writes_during_account_deletion(%L, %L)',
      target.table_name || '_' || target.column_name || '_account_deletion_guard',
      target.table_name, target.column_name, target.strategy);
  END LOOP;
END;
$$;
