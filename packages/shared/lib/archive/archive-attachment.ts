import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  trackArchiveAttachmentLevel,
  trackArchiveAttachmentMoatPerception,
  trackArchiveAttachmentReason,
} from "@/lib/metrics/archive-attachment-events";
import {
  ARCHIVE_ATTACHMENT_LEVEL_SCORE,
  ARCHIVE_ATTACHMENT_REASON_LABELS,
  ARCHIVE_ATTACHMENT_STRONG_LEVELS,
} from "@/lib/archive/archive-attachment-copy";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveAttachmentLevelId,
  ArchiveAttachmentRecord,
  ArchiveAttachmentReasonId,
  ArchiveMoatPerceptionId,
} from "@/types/archive-attachment";
import type { JournalEntry } from "@/types/journal";

export const ARCHIVE_ATTACHMENT_LAST_SHOWN_KEY = "voicememory_archive_attachment_last_shown";
export const ARCHIVE_ATTACHMENT_RECORDS_KEY = "voicememory_archive_attachment_records";
export const ARCHIVE_ATTACHMENT_PENDING_REASON_KEY =
  "voicememory_archive_attachment_pending_reason";
export const ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY =
  "voicememory_archive_attachment_pending_moat";

export const ARCHIVE_ATTACHMENT_MIN_REFLECTIONS = 5;
export const ARCHIVE_ATTACHMENT_COOLDOWN_MS = 14 * 24 * 60 * 60 * 1000;

const MAX_RECORDS = 120;

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function archiveAgeDays(entries: JournalEntry[]): number {
  const list = eligible(entries);
  if (list.length === 0) return 0;
  const sorted = [...list].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = toDayKey(sorted[0]!.createdAt);
  const last = toDayKey(sorted[sorted.length - 1]!.createdAt);
  return Math.max(1, daysBetweenKeys(first, last) + 1);
}

function readRecords(): ArchiveAttachmentRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(ARCHIVE_ATTACHMENT_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ArchiveAttachmentRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(rows: ArchiveAttachmentRecord[]): void {
  getStorage()?.setItem(
    ARCHIVE_ATTACHMENT_RECORDS_KEY,
    JSON.stringify(rows.slice(-MAX_RECORDS)),
  );
}

export function canShowArchiveAttachmentPrompt(
  now = Date.now(),
  entriesInput?: JournalEntry[],
): boolean {
  const store = getStorage();
  if (!store) return false;

  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const { reflectionCount } = buildArchiveValueSnapshot(entries);
  if (reflectionCount < ARCHIVE_ATTACHMENT_MIN_REFLECTIONS) return false;

  const last = store.getItem(ARCHIVE_ATTACHMENT_LAST_SHOWN_KEY);
  if (!last) return true;
  return now - new Date(last).getTime() >= ARCHIVE_ATTACHMENT_COOLDOWN_MS;
}

export function markArchiveAttachmentPromptShown(): void {
  getStorage()?.setItem(ARCHIVE_ATTACHMENT_LAST_SHOWN_KEY, new Date().toISOString());
}

export function shouldShowArchiveAttachmentReasonPrompt(): {
  attributionId: string;
  level: ArchiveAttachmentLevelId;
} | null {
  const store = getStorage();
  if (!store) return null;
  const raw = store.getItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as {
      attributionId: string;
      level: ArchiveAttachmentLevelId;
      answered?: boolean;
    };
    if (parsed.answered || !parsed.attributionId || !parsed.level) return null;
    if (!ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(parsed.level)) return null;
    return { attributionId: parsed.attributionId, level: parsed.level };
  } catch {
    return null;
  }
}

export function saveArchiveAttachmentLevel(
  level: ArchiveAttachmentLevelId,
  entriesInput?: JournalEntry[],
): ArchiveAttachmentRecord {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const reflectionCount = buildArchiveValueSnapshot(entries).reflectionCount;
  const ageDays = archiveAgeDays(entries);
  const score = ARCHIVE_ATTACHMENT_LEVEL_SCORE[level];

  const record: ArchiveAttachmentRecord = {
    id: newId("aa"),
    level,
    score,
    answeredAt: new Date().toISOString(),
    reflectionCount,
    archiveAgeDays: ageDays,
  };

  const rows = readRecords();
  rows.push(record);
  writeRecords(rows);

  trackArchiveAttachmentLevel({
    level,
    score,
    attributionId: record.id,
    reflectionCount,
    archiveAgeDays: ageDays,
  });

  markArchiveAttachmentPromptShown();

  const store = getStorage();
  if (ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(level)) {
    store?.setItem(
      ARCHIVE_ATTACHMENT_PENDING_REASON_KEY,
      JSON.stringify({ attributionId: record.id, level }),
    );
  } else {
    store?.removeItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
    queueArchiveMoatPerceptionPrompt(record.id, level);
  }

  return record;
}

function queueArchiveMoatPerceptionPrompt(
  attributionId: string,
  level: ArchiveAttachmentLevelId,
): void {
  getStorage()?.setItem(
    ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY,
    JSON.stringify({ attributionId, level }),
  );
}

export function shouldShowArchiveMoatPerceptionPrompt(): {
  attributionId: string;
  level: ArchiveAttachmentLevelId;
} | null {
  const store = getStorage();
  if (!store) return null;
  const raw = store.getItem(ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as {
      attributionId: string;
      level: ArchiveAttachmentLevelId;
      answered?: boolean;
    };
    if (parsed.answered || !parsed.attributionId || !parsed.level) return null;
    return { attributionId: parsed.attributionId, level: parsed.level };
  } catch {
    return null;
  }
}

export function saveArchiveMoatPerception(
  perception: ArchiveMoatPerceptionId,
  context: { attributionId: string; level: ArchiveAttachmentLevelId },
): void {
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === context.attributionId);
  const answeredAt = new Date().toISOString();
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      archiveMoatPerception: perception,
      moatPerceptionAnsweredAt: answeredAt,
    };
    writeRecords(rows);
  }

  trackArchiveAttachmentMoatPerception({
    perception,
    attributionId: context.attributionId,
    level: context.level,
  });

  getStorage()?.removeItem(ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY);
}

export function dismissArchiveMoatPerceptionPrompt(): void {
  const store = getStorage();
  if (!store) return;
  const raw = store.getItem(ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY);
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    store.setItem(
      ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY,
      JSON.stringify({ ...parsed, answered: true }),
    );
  } catch {
    store.removeItem(ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY);
  }
}

export function saveArchiveAttachmentReason(
  reason: ArchiveAttachmentReasonId,
  context: { attributionId: string; level: ArchiveAttachmentLevelId },
): void {
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === context.attributionId);
  const answeredAt = new Date().toISOString();
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      reason,
      reasonAnsweredAt: answeredAt,
    };
    writeRecords(rows);
  }

  trackArchiveAttachmentReason({
    reason,
    attributionId: context.attributionId,
    level: context.level,
  });

  getStorage()?.removeItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
  queueArchiveMoatPerceptionPrompt(context.attributionId, context.level);
}

export function dismissArchiveAttachmentPrompt(): void {
  markArchiveAttachmentPromptShown();
  getStorage()?.removeItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
}

export function dismissArchiveAttachmentReasonPrompt(): void {
  const store = getStorage();
  if (!store) return;
  const raw = store.getItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    store.setItem(
      ARCHIVE_ATTACHMENT_PENDING_REASON_KEY,
      JSON.stringify({ ...parsed, answered: true }),
    );
  } catch {
    store.removeItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
  }
}

export function readArchiveAttachmentRecords(): ArchiveAttachmentRecord[] {
  return readRecords().slice().reverse();
}

export function attachmentReasonLabel(reason: ArchiveAttachmentReasonId): string {
  return ARCHIVE_ATTACHMENT_REASON_LABELS[reason];
}

export function clearArchiveAttachmentForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(ARCHIVE_ATTACHMENT_LAST_SHOWN_KEY);
  store.removeItem(ARCHIVE_ATTACHMENT_RECORDS_KEY);
  store.removeItem(ARCHIVE_ATTACHMENT_PENDING_REASON_KEY);
  store.removeItem(ARCHIVE_ATTACHMENT_PENDING_MOAT_KEY);
}
