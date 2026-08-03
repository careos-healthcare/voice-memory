-- Opt-in encrypted sync-key recovery. The recovery secret and plaintext sync
-- key are never sent to or stored by the server.
CREATE TABLE IF NOT EXISTS sync_recovery_envelopes (
  user_id text PRIMARY KEY,
  owner_archive_id text NOT NULL,
  key_epoch integer NOT NULL CHECK (key_epoch > 0),
  envelope_revision integer NOT NULL CHECK (envelope_revision > 0),
  envelope jsonb NOT NULL,
  envelope_digest text NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS sync_recovery_envelopes_updated_idx
  ON sync_recovery_envelopes (updated_at DESC);

DO $$
BEGIN
  IF to_regprocedure('block_writes_during_account_deletion()') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS block_account_deletion_writes_sync_recovery_envelopes
      ON sync_recovery_envelopes;
    CREATE TRIGGER block_account_deletion_writes_sync_recovery_envelopes
      BEFORE INSERT OR UPDATE ON sync_recovery_envelopes
      FOR EACH ROW EXECUTE FUNCTION
        block_writes_during_account_deletion('user_id', 'user_id');
  END IF;
END;
$$;
