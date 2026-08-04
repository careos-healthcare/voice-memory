-- Backfill server-side profile defaults for users created before profile
-- onboarding fields existed. Safe to run more than once.

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id text PRIMARY KEY,
  focus_area text NOT NULL DEFAULT 'General',
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS focus_area text;

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean;

INSERT INTO user_profiles (user_id, focus_area, onboarding_completed)
SELECT DISTINCT user_id, 'General', true
FROM sessions
WHERE user_id IS NOT NULL AND btrim(user_id) <> ''
ON CONFLICT (user_id) DO NOTHING;

UPDATE user_profiles
SET
  focus_area = COALESCE(NULLIF(btrim(focus_area), ''), 'General'),
  onboarding_completed = true,
  updated_at = now()
WHERE
  focus_area IS NULL
  OR btrim(focus_area) = ''
  OR onboarding_completed IS DISTINCT FROM true;

ALTER TABLE user_profiles
  ALTER COLUMN focus_area SET DEFAULT 'General',
  ALTER COLUMN focus_area SET NOT NULL,
  ALTER COLUMN onboarding_completed SET DEFAULT false,
  ALTER COLUMN onboarding_completed SET NOT NULL;
