-- Adds the caregiver permissions payload to consent_grants.
--
-- Needed for redemption-code activation: issueMonitoringConsentToken (see
-- packages/shared/lib/caregiver/consent-verification.ts) is a pure function
-- of tokenId, subjectAccountId, caregiverId, permissions, and issuedAt/now.
-- Persisting permissions alongside the metadata this table already keeps
-- means a redemption endpoint can reconstruct the exact original signed
-- token on demand, rather than either storing the live token itself or
-- minting a second, differently-id'd one.
--
-- Nullable and no default: existing rows (issued before this column existed)
-- have no permissions on record and must not silently resolve to an empty
-- or all-access grant. Any redemption path must treat a null here as "cannot
-- redeem," not as a permissions value.
ALTER TABLE consent_grants
  ADD COLUMN IF NOT EXISTS permissions jsonb;
