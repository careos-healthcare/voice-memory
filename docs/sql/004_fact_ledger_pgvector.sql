-- Evidence Method — fact ledger with pgvector embeddings (idempotent)

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS fact_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  entry_id text NOT NULL,
  raw_text text NOT NULL,
  embedding vector(768) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fact_ledger_user_id_idx ON fact_ledger (user_id);

CREATE INDEX IF NOT EXISTS fact_ledger_entry_id_idx ON fact_ledger (entry_id);

CREATE INDEX IF NOT EXISTS fact_ledger_user_created_idx
  ON fact_ledger (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS fact_ledger_embedding_hnsw_idx
  ON fact_ledger USING hnsw (embedding vector_cosine_ops);
