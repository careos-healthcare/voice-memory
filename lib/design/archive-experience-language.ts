/**
 * Preferred archive vocabulary — avoid duplicate product concepts.
 */

export const ARCHIVE_LANGUAGE = {
  archive: "Archive",
  belief: "Belief",
  evidence: "Evidence",
  change: "Change",
  reflection: "Reflection",
} as const;

/** User-facing terms to prefer over legacy labels on archive surfaces. */
export const ARCHIVE_LANGUAGE_PREFERRED: Record<string, string> = {
  pattern: "belief",
  theory: "belief",
  insight: "evidence",
  finding: "evidence",
  observation: "reflection",
};

/**
 * Phrases that should not headline archive experience pages
 * when an archive term already applies.
 */
export const ARCHIVE_LANGUAGE_FORBIDDEN_HEADLINES = [
  "Pattern review",
  "Theory changes",
  "New insight",
  "Key finding",
] as const;

export const DISCOVER_ARCHIVE_CHANGE_LOG_HEADING =
  "What changed since your last visit?";

export const BLIND_SPOT_ARCHIVE_EVIDENCE_LEAD =
  "This is one reason your archive currently believes what it believes.";
