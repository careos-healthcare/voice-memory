/**
 * Canonical ArchiveMe positioning for the marketing surface.
 *
 * Mirrors apps/voicememory_mobile/lib/product/auditable_change_positioning.dart.
 * These three strings must stay byte-identical to their Dart counterparts.
 */

/** The product category. Leads wherever a category is named. */
export const ARCHIVE_ME_CATEGORY = "Auditable personal change.";

/** The promise. Leads wherever a headline is shown. */
export const ARCHIVE_ME_PRIMARY_PROMISE =
  "See what repeated. See what changed. Verify it in your own words.";

/** The full sentence. Leads wherever a paragraph explains the product. */
export const ARCHIVE_ME_POSITIONING =
  "A private change ledger that shows exactly what repeated, what changed, the words proving it, and lets you correct the record.";

/** @deprecated Use {@link ARCHIVE_ME_POSITIONING}. */
export const VOICEMEMORY_ARCHIVE_POSITIONING = ARCHIVE_ME_POSITIONING;

/** @deprecated Use {@link ARCHIVE_ME_PRIMARY_PROMISE}. */
export const ARCHIVE_IDENTITY_ONE_LINER = ARCHIVE_ME_PRIMARY_PROMISE;
