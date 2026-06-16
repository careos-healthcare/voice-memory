/** Archive Belief Dominance v2 — user-visible reframes (routes unchanged). */

export const BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF = "Evidence for belief";

export const BELIEF_DOMINANCE_ARCHIVE_CHANGE = "Archive change";

export const BELIEF_DOMINANCE_ARCHIVE_TRUST = "Archive trust";

/** Headlines that must not outrank archive belief on public surfaces. */
export const COMPETING_PRODUCT_HEADLINES = [
  "Blind Spot",
  "Blind Spots",
  "Pattern Review",
  "Theories",
  "Theory",
  "Insights",
  "Archive Insight",
  "What keeps returning",
] as const;

export const BELIEF_DOMINANCE_STICKY_SURFACES = [
  "app/archive-belief/page.tsx",
  "app/discover/page.tsx",
  "app/archive-detail/page.tsx",
  "app/memory/page.tsx",
] as const;
