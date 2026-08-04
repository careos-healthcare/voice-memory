-- Content-free metadata required for auditable reserve/commit/release usage.
-- Safe to rerun. No journal text, transcript, prompt, quote, or model output.

ALTER TABLE usage_reservations
  ADD COLUMN IF NOT EXISTS units_released integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_input_units integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_output_units integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS audio_seconds integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS policy_version text NOT NULL DEFAULT 'legacy',
  ADD COLUMN IF NOT EXISTS safe_result_code text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'usage_reservations_safe_result_code_check'
  ) THEN
    ALTER TABLE usage_reservations
      ADD CONSTRAINT usage_reservations_safe_result_code_check
      CHECK (
        safe_result_code IS NULL OR
        safe_result_code ~ '^[a-z][a-z0-9_]{0,63}$'
      );
  END IF;
END
$$;
