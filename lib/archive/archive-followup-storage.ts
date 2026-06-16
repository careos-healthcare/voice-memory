import type {
  ArchiveFollowupAnswerRecord,
  ArchiveFollowupAnswerValue,
  ImmediateNoticeKind,
} from "@/types/immediate-engagement";

export const ARCHIVE_FOLLOWUP_ANSWER_KEY = "voicememory_archive_followup_answer";

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readRecords(): ArchiveFollowupAnswerRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(ARCHIVE_FOLLOWUP_ANSWER_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ArchiveFollowupAnswerRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(records: ArchiveFollowupAnswerRecord[]): void {
  getStorage()?.setItem(
    ARCHIVE_FOLLOWUP_ANSWER_KEY,
    JSON.stringify(records.slice(-200)),
  );
}

export function readArchiveFollowupAnswers(): ArchiveFollowupAnswerRecord[] {
  return readRecords();
}

export function readArchiveFollowupAnswerForFollowUp(
  followUpId: string,
): ArchiveFollowupAnswerRecord | null {
  return readRecords().find((r) => r.followUpId === followUpId) ?? null;
}

export function clearArchiveFollowupAnswersForEval(): void {
  getStorage()?.removeItem(ARCHIVE_FOLLOWUP_ANSWER_KEY);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

export function persistArchiveFollowupAnswer(input: {
  followUpId: string;
  entryId: string;
  noticeKind: ImmediateNoticeKind;
  answer: ArchiveFollowupAnswerValue;
}): ArchiveFollowupAnswerRecord {
  const records = readRecords();
  const existing = records.find((r) => r.followUpId === input.followUpId);
  if (existing) return existing;

  const record: ArchiveFollowupAnswerRecord = {
    id: newId("afa"),
    followUpId: input.followUpId,
    entryId: input.entryId,
    noticeKind: input.noticeKind,
    answer: input.answer,
    at: new Date().toISOString(),
  };
  records.push(record);
  writeRecords(records);
  return record;
}
