-- Single-use redemption codes for delivering a caregiver consent grant to a
-- second device, without ever transmitting the signed token itself.
--
-- Deliberately its own table, not a few extra columns on consent_grants:
-- that table's own doc comments are explicit that rows there must never
-- expire and never get cleaned up. A redemption code is the opposite kind
-- of data -- short-lived by design, meant to be consumed once and then be
-- inert. Mixing the two would fight consent_grants' own stated purpose.
--
-- Two code formats for one redemption, matching the two delivery paths:
--   - link_token_hash: long, CSPRNG-random, embedded in the Universal Link,
--     extracted programmatically. Protected by length alone -- no attempt
--     cap needed, since nobody is expected to guess it.
--   - manual_code_hash: short, human-typeable, entered by hand on
--     /caregiver/consent if the link does not fire. Needs real
--     brute-force protection -- see manual_code_attempts below, checked
--     against MAX_CODE_ATTEMPTS via evaluateCodeAttempt (see
--     packages/shared/lib/auth/auth-code-policy.ts), the same pure
--     decision function the email sign-in code flow already uses.
--
-- Only hashes are ever stored -- both hashed against
-- CAREGIVER_CONSENT_HMAC_SECRET, matching how hashVerificationCode hashes
-- against AUTH_SECRET for sign-in codes, kept as a separate secret
-- deliberately so the two domains stay independent.
CREATE TABLE IF NOT EXISTS caregiver_redemption_codes (
  id text PRIMARY KEY,
  token_id text NOT NULL REFERENCES consent_grants (token_id),
  -- Non-secret lookup key shown alongside the manual code (e.g. "Reference:
  -- XY7B, Code: 482913"). A wrong manual-code guess still identifies the
  -- right row via this, so evaluateCodeAttempt's durable per-row counter
  -- actually has something to increment -- without it, a guess that misses
  -- matches no row at all, and the attempt counter below never fires.
  reference text NOT NULL,
  link_token_hash text NOT NULL,
  manual_code_hash text NOT NULL,
  manual_code_attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  redeemed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS caregiver_redemption_codes_reference_idx
  ON caregiver_redemption_codes (reference);
CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_link_idx
  ON caregiver_redemption_codes (link_token_hash);
CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_manual_idx
  ON caregiver_redemption_codes (manual_code_hash);
CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_token_idx
  ON caregiver_redemption_codes (token_id);
