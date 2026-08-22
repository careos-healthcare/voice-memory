-- Evidence Method — migrate fact_ledger embeddings from OpenAI 1536-d to Gemini 768-d
--
-- SAFETY GUARDRAILS — READ BEFORE RUNNING
--
-- 1. VECTOR EMBEDDINGS CANNOT BE PRESERVED
--    Existing 1536-d vectors cannot be cast or converted to 768-d. Any column
--    type change requires clearing embedding values and re-ingesting transcripts
--    with the Gemini embedder after migration.
--
-- 2. PRODUCTION / LIVE-DATA PROTECTION
--    TRUNCATE and ALTER below are blocked when fact_ledger contains rows unless
--    an operator sets an explicit administrative confirmation flag (see below).
--    Never run this script unattended against a production DATABASE_URL.
--
-- 3. ADMINISTRATIVE CONFIRMATION FLAG (required when rows exist)
--    After backup + re-embed plan is approved, run in the SAME session before
--    applying this file:
--
--      SET voice_memory.confirm_fact_ledger_reembed = 'yes';
--
--    Optional environment label (recommended for production ops):
--
--      SET voice_memory.environment = 'production';
--
--    psql example:
--      psql "$DATABASE_URL" \
--        -c "SET voice_memory.confirm_fact_ledger_reembed = 'yes';" \
--        -f docs/sql/005_fact_ledger_gemini_768.sql
--
-- 4. IDEMPOTENT SKIP
--    If embedding is already vector(768), this migration is a no-op and preserves
--    existing rows and embeddings.
--
-- 5. EMPTY / DEV DATABASES
--    When fact_ledger has zero rows, migration proceeds without the flag.

DO $fact_ledger_gemini_768$
DECLARE
  ledger_exists boolean;
  row_count bigint;
  distinct_users bigint;
  embedding_type text;
  confirm_flag text;
  env_label text;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'fact_ledger'
  ) INTO ledger_exists;

  IF NOT ledger_exists THEN
    RAISE NOTICE '005_fact_ledger_gemini_768: fact_ledger absent — nothing to migrate';
    RETURN;
  END IF;

  SELECT format_type(a.atttypid, a.atttypmod)
  INTO embedding_type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'fact_ledger'
    AND a.attname = 'embedding'
    AND NOT a.attisdropped;

  IF embedding_type = 'vector(768)' THEN
    RAISE NOTICE '005_fact_ledger_gemini_768: embedding already vector(768) — preserving existing rows and embeddings';
    RETURN;
  END IF;

  SELECT COUNT(*)::bigint, COUNT(DISTINCT user_id)::bigint
  INTO row_count, distinct_users
  FROM fact_ledger;

  confirm_flag := current_setting('voice_memory.confirm_fact_ledger_reembed', true);
  env_label := current_setting('voice_memory.environment', true);

  IF row_count > 0 THEN
    IF confirm_flag IS DISTINCT FROM 'yes' THEN
      RAISE EXCEPTION
        '005_fact_ledger_gemini_768 BLOCKED: fact_ledger has % row(s) across % user(s). '
        'Embeddings cannot be preserved when changing vector dimensions (% → vector(768)). '
        'Back up raw_text, plan full re-embed, then run: '
        'SET voice_memory.confirm_fact_ledger_reembed = ''yes''; '
        'before re-applying this migration.',
        row_count,
        distinct_users,
        COALESCE(embedding_type, 'unknown');
    END IF;

    IF env_label = 'production' THEN
      RAISE NOTICE
        '005_fact_ledger_gemini_768: production confirmation acknowledged — '
        'truncating % fact_ledger row(s) for % user(s); re-embed required after ALTER',
        row_count,
        distinct_users;
    ELSE
      RAISE WARNING
        '005_fact_ledger_gemini_768: destructive migration confirmed — '
        'truncating % fact_ledger row(s); existing embeddings will be discarded',
        row_count;
    END IF;
  ELSE
    RAISE NOTICE '005_fact_ledger_gemini_768: fact_ledger empty — safe to alter embedding column';
  END IF;

  EXECUTE 'DROP INDEX IF EXISTS fact_ledger_embedding_hnsw_idx';
  EXECUTE 'TRUNCATE fact_ledger';
  EXECUTE 'ALTER TABLE fact_ledger ALTER COLUMN embedding TYPE vector(768)';
  EXECUTE '
    CREATE INDEX IF NOT EXISTS fact_ledger_embedding_hnsw_idx
      ON fact_ledger USING hnsw (embedding vector_cosine_ops)';

  RAISE NOTICE '005_fact_ledger_gemini_768: migration complete — re-ingest transcripts to repopulate embeddings';
END
$fact_ledger_gemini_768$;
