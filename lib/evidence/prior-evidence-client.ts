/**
 * Client-side prior evidence contract. Like mobile, web may send only stable
 * ids, timestamps, and short sanitized reflection snippets. Raw transcripts
 * and prompt text are never included.
 */

import type { JournalEntry } from "@/types/journal";

export interface PriorEvidenceRef {
  id: string;
  createdAt: string;
  exactLanguagePattern?: string;
  concreteObservation?: string;
}

export const MAX_PRIOR_EVIDENCE_REFS = 3;
export const MAX_PRIOR_EVIDENCE_TEXT_CHARS = 120;

const BLOCKED = [
  "[draft]",
  "saved locally",
  "saved on this device",
  "transcribe when connected",
  "cloud processing pending",
  "system prompt",
  "developer message",
  "ignore previous instructions",
  "reveal your instructions",
  "recorded reflection",
  "entry language",
];
const SECRET_PATTERNS = [
  /\bsk-[a-z0-9_-]{16,}\b/i,
  /\b(?:api[_ -]?key|secret[_ -]?key|access[_ -]?token|password)\s*[:=]\s*\S+/i,
  /\bbearer\s+[a-z0-9._~+/-]+=*/i,
  /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/i,
];

function safeReflectionSnippet(value: string | undefined): string | undefined {
  if (typeof value !== "string") return undefined;
  const cleaned = value
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .replace(/[\u202a-\u202e\u2066-\u2069\u200b-\u200d\ufeff]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (
    !cleaned ||
    BLOCKED.some((text) => cleaned.toLowerCase().includes(text)) ||
    SECRET_PATTERNS.some((pattern) => pattern.test(cleaned))
  ) {
    return undefined;
  }
  return cleaned.length <= MAX_PRIOR_EVIDENCE_TEXT_CHARS
    ? cleaned
    : `${cleaned.slice(0, MAX_PRIOR_EVIDENCE_TEXT_CHARS - 1).trimEnd()}…`;
}

export function buildPriorEvidenceRefs(
  entries: JournalEntry[],
  excludeId?: string,
): PriorEvidenceRef[] {
  return entries
    .filter((entry) => entry.id !== excludeId)
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
    .slice(0, MAX_PRIOR_EVIDENCE_REFS)
    .map((entry) => {
      const exactLanguagePattern = safeReflectionSnippet(
        entry.reflection.exactLanguagePattern,
      );
      const concreteObservation = safeReflectionSnippet(
        entry.reflection.concreteObservation,
      );
      return {
        id: entry.id,
        createdAt: entry.createdAt,
        ...(exactLanguagePattern ? { exactLanguagePattern } : {}),
        ...(concreteObservation ? { concreteObservation } : {}),
      };
    });
}
