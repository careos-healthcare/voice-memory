import "server-only";

/** Mirrors mobile ArchiveEvidenceQuality.minUsableChars. */
export const MIN_USABLE_LEDGER_TEXT_CHARS = 24;

/** Mirrors mobile ArchiveEvidenceQuality.minStrongChars. */
export const MIN_STRONG_LEDGER_TEXT_CHARS = 40;

/** Mirrors mobile ArchiveEvidenceQualityGate.minProofEntryCount. */
export const MIN_STRONG_LEDGER_ENTRIES_FOR_PROOF = 3;

/** Mirrors mobile AppConfig.patternReviewReflectionTarget. */
export const MIN_USABLE_LEDGER_ENTRIES_FOR_PATTERNS = 5;

export function isUsableLedgerText(rawText: string): boolean {
  return rawText.trim().length >= MIN_USABLE_LEDGER_TEXT_CHARS;
}

export function isStrongLedgerText(rawText: string): boolean {
  return rawText.trim().length >= MIN_STRONG_LEDGER_TEXT_CHARS;
}

export interface LedgerEntryLike {
  entryId: string;
  rawText: string;
  createdAt: string;
}

export function filterUsableLedgerEntries<T extends LedgerEntryLike>(
  entries: readonly T[],
): T[] {
  return entries.filter((entry) => isUsableLedgerText(entry.rawText));
}

export function filterStrongLedgerEntries<T extends LedgerEntryLike>(
  entries: readonly T[],
): T[] {
  return entries.filter((entry) => isStrongLedgerText(entry.rawText));
}
