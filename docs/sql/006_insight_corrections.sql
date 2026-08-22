-- Evidence Method — insight correction suppressions (idempotent)

CREATE TABLE IF NOT EXISTS insight_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  insight_id text NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS insight_corrections_user_insight_idx
  ON insight_corrections (user_id, insight_id);

CREATE INDEX IF NOT EXISTS insight_corrections_user_created_idx
  ON insight_corrections (user_id, created_at DESC);
