/**
 * Evidence authority — how much a piece of evidence is allowed to say,
 * separate from whether it was found. Mirrors the mobile Memory
 * Authority Framing ids so the two sides speak the same language.
 */

export const AUTHORITY_STATES = [
  "current",
  "stale",
  "confirmed",
  "superseded",
  "conflicting",
  "background",
  "blocked",
  "fresh",
] as const;

export type AuthorityState = (typeof AUTHORITY_STATES)[number];

export const INFLUENCE_LEVELS = [
  "blocked",
  "suppress",
  "background",
  "compare",
  "high_authority",
] as const;

export type InfluenceLevel = (typeof INFLUENCE_LEVELS)[number];

/** Whether evidence at this level may enter the packet at all. */
export function influenceAdmitsEvidence(level: InfluenceLevel): boolean {
  return level === "background" || level === "compare" || level === "high_authority";
}

/**
 * Stable reason ids — the only vocabulary explanations and analytics
 * may use. Never dynamic, never user text.
 */
export const EVIDENCE_REASON_IDS = [
  "recent_supported",
  "user_confirmed",
  "older_unreinforced",
  "changed_later",
  "mixed_evidence",
  "memory_off",
  "fresh_entry",
  "unapproved",
  "source_current",
  "source_background",
  "generated_text",
  "unknown_source",
] as const;

export type EvidenceReasonId = (typeof EVIDENCE_REASON_IDS)[number];

/**
 * "Why this source was used" — internal, fixed copy per reason id.
 * Cautious language only; no certainty claims, no private content.
 */
const REASON_EXPLANATIONS: Record<EvidenceReasonId, string> = {
  recent_supported: "Recent supporting evidence from the archive.",
  user_confirmed: "The user confirmed this connection earlier.",
  older_unreinforced: "Older evidence that was not reinforced recently.",
  changed_later: "Newer entries moved on after this evidence.",
  mixed_evidence: "The evidence points in more than one direction.",
  memory_off: "Memory is off, so archive evidence is not used here.",
  fresh_entry: "This entry is being kept separate from connections.",
  unapproved: "This entry was not approved for connections.",
  source_current: "Current factual source information.",
  source_background: "Background information, treated cautiously.",
  generated_text: "Generated text is not treated as evidence.",
  unknown_source: "Unknown source type, not used as evidence.",
};

export function explainEvidenceReason(reasonId: EvidenceReasonId): string {
  return REASON_EXPLANATIONS[reasonId];
}

/**
 * Influence ordering for ranking inside a packet — higher number means
 * the item earns a higher slot when the packet is capped.
 */
export const INFLUENCE_RANK: Record<InfluenceLevel, number> = {
  high_authority: 3,
  compare: 2,
  background: 1,
  suppress: 0,
  blocked: 0,
};
