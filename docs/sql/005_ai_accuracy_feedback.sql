CREATE TABLE IF NOT EXISTS ai_accuracy_feedback (
  user_id text NOT NULL,
  conclusion_id text NOT NULL,
  engine text NOT NULL,
  confidence_percentage integer NOT NULL
    CHECK (confidence_percentage BETWEEN 0 AND 100),
  feedback_state text NOT NULL
    CHECK (feedback_state IN ('pending', 'correct', 'incorrect', 'later')),
  feedback_timestamp timestamptz NOT NULL,
  correction_note text,
  node_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  edge_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, conclusion_id)
);

ALTER TABLE ai_accuracy_feedback
  ADD COLUMN IF NOT EXISTS edge_ids jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE ai_accuracy_feedback
  DROP CONSTRAINT IF EXISTS ai_accuracy_feedback_feedback_state_check;

UPDATE ai_accuracy_feedback
SET feedback_state = 'later'
WHERE feedback_state = 'deferred';

ALTER TABLE ai_accuracy_feedback
  ADD CONSTRAINT ai_accuracy_feedback_feedback_state_check
  CHECK (feedback_state IN ('pending', 'correct', 'incorrect', 'later'));

CREATE INDEX IF NOT EXISTS ai_accuracy_feedback_user_updated_idx
  ON ai_accuracy_feedback (user_id, updated_at DESC);
