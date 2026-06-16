import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import type { FounderTestRecord } from "@/types/founder-test";

export const ARCHIVE_UNDERSTANDING_PROMPT =
  "Can a new user explain ArchiveMe in one sentence?";

export interface ArchiveUnderstandingValidationReport {
  prompt: string;
  participantsAsked: number;
  canExplainYes: number;
  canExplainNo: number;
  canExplainRate: number | null;
  verbatims: string[];
  lines: string[];
}

function rateYes(records: FounderTestRecord[]): number | null {
  const asked = records.filter((r) => r.session.archiveUnderstandingCanExplain !== undefined);
  if (asked.length === 0) return null;
  const yes = asked.filter((r) => r.session.archiveUnderstandingCanExplain === true).length;
  return yes / asked.length;
}

export function buildArchiveUnderstandingValidationReport(
  recordsInput?: FounderTestRecord[],
): ArchiveUnderstandingValidationReport {
  const records = recordsInput ?? readFounderTestRecords();
  const asked = records.filter((r) => r.session.archiveUnderstandingCanExplain !== undefined);
  const yes = asked.filter((r) => r.session.archiveUnderstandingCanExplain === true).length;
  const no = asked.filter((r) => r.session.archiveUnderstandingCanExplain === false).length;
  const verbatims = records
    .map((r) => r.session.archiveUnderstandingVerbatim?.trim())
    .filter((v): v is string => Boolean(v));

  const rate = rateYes(records);
  const lines = [
    `${ARCHIVE_UNDERSTANDING_PROMPT}`,
    `Asked: ${asked.length} · Yes: ${yes} · No: ${no}`,
    rate === null
      ? "No understanding interviews recorded yet."
      : `Can explain in one sentence: ${Math.round(rate * 100)}%`,
  ];

  return {
    prompt: ARCHIVE_UNDERSTANDING_PROMPT,
    participantsAsked: asked.length,
    canExplainYes: yes,
    canExplainNo: no,
    canExplainRate: rate,
    verbatims: verbatims.slice(0, 12),
    lines,
  };
}
