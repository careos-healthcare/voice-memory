/**
 * The single source of truth for consent token lifetimes.
 *
 * Each role gets exactly ONE declaration. These constants are the only place a
 * default TTL may be written down: `scripts/validate-consent-ttl.mjs` fails the
 * build if a second default appears anywhere in the consent code, because a
 * duplicated default is how a "shortened" TTL silently stays long on the other
 * path.
 *
 * These bound how long a token that was leaked *without anyone noticing* keeps
 * working. A token whose withdrawal the owner does know about is killed by the
 * server-side revocation list in
 * `packages/shared/lib/server/consent-revocation-store.ts`, which `verify`
 * consults on every call — so TTL is a backstop, not the primary control, and
 * is set for the re-consent cadence a real relationship can carry.
 */

/**
 * Caregiver monitoring — 7 days.
 *
 * Caregiver access is an active-support arrangement between people who are in
 * contact at least weekly; a caregiver who has not been in touch for a week has
 * no standing claim on a live read path into someone's journal. Weekly
 * re-consent is friction the archive owner pays, and it is friction that runs
 * in their favour: the default is that access lapses, and continuing requires
 * an affirmative act by the person whose journal it is. That matters most
 * exactly where this feature is riskiest — a caregiver the writer is not free
 * to say no to has to ask again every week rather than once a month.
 */
export const CAREGIVER_CONSENT_DEFAULT_TTL_MS = 1000 * 60 * 60 * 24 * 7;

/**
 * Coach / client — 30 days.
 *
 * A professional coaching engagement is reviewed and billed on roughly a
 * monthly cycle, so a month is the shortest window that does not interrupt an
 * ongoing engagement mid-stream. It is a third of the previous 90 days, and a
 * coach relationship is arms-length and contractual in a way a caregiver
 * relationship is not, which is why it can carry a longer lifetime than the
 * caregiver default.
 */
export const COACH_CONSENT_DEFAULT_TTL_MS = 1000 * 60 * 60 * 24 * 30;

/** Resolves an explicit caller TTL against the single caregiver default. */
export function resolveCaregiverConsentTtlMs(ttlMs?: number): number {
  return ttlMs ?? CAREGIVER_CONSENT_DEFAULT_TTL_MS;
}

/** Resolves an explicit caller TTL against the single coach default. */
export function resolveCoachConsentTtlMs(ttlMs?: number): number {
  return ttlMs ?? COACH_CONSENT_DEFAULT_TTL_MS;
}
