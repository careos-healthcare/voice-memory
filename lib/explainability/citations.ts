import type {
  EvidenceRole,
  EvidenceSourceScope,
  PriorSnippetField,
  TranscriptEvidenceCitation,
} from "@/types/explainability";

export interface BuildCitationOptions {
  role?: EvidenceRole;
  sourceScope?: EvidenceSourceScope;
  sourceField?: PriorSnippetField;
  /** Zero-based occurrence when the same quote appears more than once. */
  occurrence?: number;
}

/** Builds a deterministic, exact citation without normalizing either string. */
export function buildExactTranscriptCitation(
  entryId: string,
  canonicalTranscript: string,
  quote: string,
  options: BuildCitationOptions = {},
): TranscriptEvidenceCitation | null {
  if (!entryId || !quote) return null;
  const occurrence = options.occurrence ?? 0;
  if (!Number.isInteger(occurrence) || occurrence < 0) return null;

  let startUtf16 = -1;
  let fromIndex = 0;
  for (let index = 0; index <= occurrence; index += 1) {
    startUtf16 = canonicalTranscript.indexOf(quote, fromIndex);
    if (startUtf16 < 0) return null;
    fromIndex = startUtf16 + 1;
  }
  const endUtf16 = startUtf16 + quote.length;
  if (
    !isUtf16Boundary(canonicalTranscript, startUtf16) ||
    !isUtf16Boundary(canonicalTranscript, endUtf16)
  ) {
    return null;
  }

  return {
    sourceEntryId: entryId,
    exactQuote: quote,
    confidenceScore: 1,
    entryId,
    quote,
    startUtf16,
    endUtf16,
    role: options.role ?? "support",
    ...(options.sourceScope ? { sourceScope: options.sourceScope } : {}),
    ...(options.sourceField ? { sourceField: options.sourceField } : {}),
  };
}

export function isUtf16Boundary(value: string, offset: number): boolean {
  if (!Number.isInteger(offset) || offset < 0 || offset > value.length) {
    return false;
  }
  if (offset === 0 || offset === value.length) return true;
  const previous = value.charCodeAt(offset - 1);
  const next = value.charCodeAt(offset);
  const splitsPair =
    previous >= 0xd800 &&
    previous <= 0xdbff &&
    next >= 0xdc00 &&
    next <= 0xdfff;
  return !splitsPair;
}
