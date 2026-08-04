/**
 * Emotional Elegance — human phrasing for archive movement (no new analysis).
 */

export const ARCHIVE_EMOTIONAL = {
  confidenceIncreased: "The archive has become more certain.",
  evidenceAdded: "New experiences supported this view.",
  theoryWeakened: "Recent moments challenged this belief.",
  theoryRetired: "The archive no longer sees enough evidence.",
  confidenceDecreased: "Recent moments challenged this belief.",
  contradictingEvidence: "New moments pulled in a different direction.",
  stillChanging: "This belief is still changing.",
  notCertainYet: "The archive is not certain yet.",
} as const;

const REPLACEMENTS: ReadonlyArray<{ pattern: RegExp; replacement: string }> = [
  {
    pattern: /confidence increased(?:\s+\d+\s*%?)?/gi,
    replacement: ARCHIVE_EMOTIONAL.confidenceIncreased,
  },
  {
    pattern: /confidence decreased(?:\s+\d+\s*%?)?/gi,
    replacement: ARCHIVE_EMOTIONAL.confidenceDecreased,
  },
  { pattern: /evidence added/gi, replacement: ARCHIVE_EMOTIONAL.evidenceAdded },
  { pattern: /theory weakened/gi, replacement: ARCHIVE_EMOTIONAL.theoryWeakened },
  { pattern: /theory retired/gi, replacement: ARCHIVE_EMOTIONAL.theoryRetired },
];

/** Map analytical archive phrases to emotional equivalents for display. */
export function toArchiveEmotionalCopy(text: string): string {
  let out = text.replace(/\s+/g, " ").trim();
  for (const { pattern, replacement } of REPLACEMENTS) {
    out = out.replace(pattern, replacement);
  }
  return out;
}

export function emotionalConfidenceLine(_deltaPercent?: number): string {
  return ARCHIVE_EMOTIONAL.confidenceIncreased;
}

export function emotionalWeakenedLine(): string {
  return ARCHIVE_EMOTIONAL.theoryWeakened;
}

export function emotionalEvidenceAddedLine(): string {
  return ARCHIVE_EMOTIONAL.evidenceAdded;
}

export function emotionalRetiredLine(): string {
  return ARCHIVE_EMOTIONAL.theoryRetired;
}
