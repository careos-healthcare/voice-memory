import { buildDefaultFounderTestChecklist } from "@/lib/founder-test/founder-test-checklist";
import type { ProductDescriptionCategory } from "@/types/archive-as-product-validation";
import type {
  FounderTestChecklistItem,
  FounderTestParticipant,
  FounderTestRecord,
  FounderTestSession,
} from "@/types/founder-test";

export const FOUNDER_TEST_STORAGE_KEY = "voicememory_founder_test_sessions";

const MAX_RECORDS = 100;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function normalizeParticipant(raw: unknown): FounderTestParticipant | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.id !== "string" || typeof row.label !== "string") return null;
  if (typeof row.startedAt !== "string") return null;
  return {
    id: row.id,
    label: row.label,
    startedAt: row.startedAt,
    completedAt: typeof row.completedAt === "string" ? row.completedAt : undefined,
    targetReflectionCount:
      typeof row.targetReflectionCount === "number" ? row.targetReflectionCount : 5,
    notes: typeof row.notes === "string" ? row.notes : undefined,
  };
}

function normalizeSession(raw: unknown): FounderTestSession | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.participantId !== "string") return null;
  if (typeof row.createdAt !== "string" || typeof row.updatedAt !== "string") return null;

  const reaction = row.firstBlindSpotReaction;
  const validReactions = new Set([
    "obvious",
    "interesting",
    "surprising",
    "uncomfortably_accurate",
    "completely_wrong",
  ]);

  return {
    participantId: row.participantId,
    reflectionCount: typeof row.reflectionCount === "number" ? row.reflectionCount : 0,
    reachedFiveReflections: Boolean(row.reachedFiveReflections),
    openedBlindSpots: Boolean(row.openedBlindSpots),
    openedDiscover: Boolean(row.openedDiscover),
    firstBlindSpotReaction:
      typeof reaction === "string" && validReactions.has(reaction)
        ? (reaction as FounderTestSession["firstBlindSpotReaction"])
        : undefined,
    returnedWithin7Days:
      typeof row.returnedWithin7Days === "boolean" ? row.returnedWithin7Days : undefined,
    understoodChatGptDifference:
      typeof row.understoodChatGptDifference === "boolean"
        ? row.understoodChatGptDifference
        : undefined,
    wouldPay: typeof row.wouldPay === "boolean" ? row.wouldPay : undefined,
    mainQuote: typeof row.mainQuote === "string" ? row.mainQuote : undefined,
    biggestConfusion: typeof row.biggestConfusion === "string" ? row.biggestConfusion : undefined,
    framingAccuracyPreference:
      row.framingAccuracyPreference === "blind_spot" ||
      row.framingAccuracyPreference === "working_theory" ||
      row.framingAccuracyPreference === "no_difference"
        ? row.framingAccuracyPreference
        : undefined,
    discoverExpectationVerbatim:
      typeof row.discoverExpectationVerbatim === "string"
        ? row.discoverExpectationVerbatim
        : undefined,
    discoverExpectationQuality:
      row.discoverExpectationQuality === "good" ||
      row.discoverExpectationQuality === "weak" ||
      row.discoverExpectationQuality === "unclear"
        ? row.discoverExpectationQuality
        : undefined,
    theoryCuriosityAnswer:
      row.theoryCuriosityAnswer === "yes" ||
      row.theoryCuriosityAnswer === "maybe" ||
      row.theoryCuriosityAnswer === "no"
        ? row.theoryCuriosityAnswer
        : undefined,
    returnedToCheckArchiveView:
      typeof row.returnedToCheckArchiveView === "boolean"
        ? row.returnedToCheckArchiveView
        : undefined,
    productDescriptionVerbatim:
      typeof row.productDescriptionVerbatim === "string"
        ? row.productDescriptionVerbatim
        : undefined,
    productDescriptionCategory:
      row.productDescriptionCategory === "archive_model" ||
      row.productDescriptionCategory === "insight_tool" ||
      row.productDescriptionCategory === "journal_mode" ||
      row.productDescriptionCategory === "mixed" ||
      row.productDescriptionCategory === "unclear"
        ? (row.productDescriptionCategory as ProductDescriptionCategory)
        : undefined,
    openedArchiveBeforeDiscoverPostFive:
      typeof row.openedArchiveBeforeDiscoverPostFive === "boolean"
        ? row.openedArchiveBeforeDiscoverPostFive
        : undefined,
    reflectionSixFeltStronger:
      typeof row.reflectionSixFeltStronger === "boolean"
        ? row.reflectionSixFeltStronger
        : undefined,
    voluntaryArchiveReturn:
      typeof row.voluntaryArchiveReturn === "boolean" ? row.voluntaryArchiveReturn : undefined,
    archiveUnderstandingCanExplain:
      typeof row.archiveUnderstandingCanExplain === "boolean"
        ? row.archiveUnderstandingCanExplain
        : undefined,
    archiveUnderstandingVerbatim:
      typeof row.archiveUnderstandingVerbatim === "string"
        ? row.archiveUnderstandingVerbatim
        : undefined,
    onboardingProductPerceptionVerbatim:
      typeof row.onboardingProductPerceptionVerbatim === "string"
        ? row.onboardingProductPerceptionVerbatim
        : undefined,
    onboardingProductPerceptionCategory:
      typeof row.onboardingProductPerceptionCategory === "string"
        ? row.onboardingProductPerceptionCategory
        : undefined,
    onboardingProductPerceptionSuccess:
      typeof row.onboardingProductPerceptionSuccess === "boolean"
        ? row.onboardingProductPerceptionSuccess
        : undefined,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function normalizeChecklist(raw: unknown): FounderTestChecklistItem[] {
  if (!Array.isArray(raw)) return buildDefaultFounderTestChecklist();
  const items: FounderTestChecklistItem[] = [];
  for (const row of raw) {
    if (!row || typeof row !== "object") continue;
    const item = row as Record<string, unknown>;
    if (typeof item.id !== "string" || typeof item.label !== "string") continue;
    items.push({
      id: item.id,
      label: item.label,
      completed: Boolean(item.completed),
      completedAt: typeof item.completedAt === "string" ? item.completedAt : undefined,
    });
  }

  if (items.length === 0) return buildDefaultFounderTestChecklist();
  return items;
}

function normalizeRecord(raw: unknown): FounderTestRecord | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  const participant = normalizeParticipant(row.participant);
  const session = normalizeSession(row.session);
  if (!participant || !session) return null;
  if (session.participantId !== participant.id) return null;
  return {
    participant,
    session,
    checklist: normalizeChecklist(row.checklist),
  };
}

function readAllRecords(): FounderTestRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(FOUNDER_TEST_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalizeRecord)
      .filter((r): r is FounderTestRecord => Boolean(r))
      .sort((a, b) => b.participant.startedAt.localeCompare(a.participant.startedAt));
  } catch {
    return [];
  }
}

function writeAllRecords(records: FounderTestRecord[]): void {
  getStorage()?.setItem(FOUNDER_TEST_STORAGE_KEY, JSON.stringify(records.slice(0, MAX_RECORDS)));
}

export function readFounderTestRecords(): FounderTestRecord[] {
  return readAllRecords();
}

export function readFounderTestSessions(): FounderTestSession[] {
  return readAllRecords().map((r) => r.session);
}

export function readFounderTestParticipant(
  participantId: string,
): FounderTestRecord | null {
  return readAllRecords().find((r) => r.participant.id === participantId) ?? null;
}

export function createFounderTestParticipant(label: string): FounderTestRecord {
  const trimmed = label.trim() || "Participant";
  const now = new Date().toISOString();
  const id = newId("ftp");

  const record: FounderTestRecord = {
    participant: {
      id,
      label: trimmed,
      startedAt: now,
      targetReflectionCount: 5,
    },
    session: {
      participantId: id,
      reflectionCount: 0,
      reachedFiveReflections: false,
      openedBlindSpots: false,
      openedDiscover: false,
      createdAt: now,
      updatedAt: now,
    },
    checklist: buildDefaultFounderTestChecklist(),
  };

  const records = readAllRecords();
  records.unshift(record);
  writeAllRecords(records);
  return record;
}

export function updateFounderTestSession(
  participantId: string,
  patch: Partial<FounderTestSession>,
): FounderTestSession | null {
  const records = readAllRecords();
  const index = records.findIndex((r) => r.participant.id === participantId);
  if (index < 0) return null;

  const now = new Date().toISOString();
  const current = records[index]!;
  const nextSession: FounderTestSession = {
    ...current.session,
    ...patch,
    participantId,
    updatedAt: now,
  };

  records[index] = { ...current, session: nextSession };
  writeAllRecords(records);
  return nextSession;
}

export function updateFounderTestParticipant(
  participantId: string,
  patch: Partial<FounderTestParticipant>,
): FounderTestParticipant | null {
  const records = readAllRecords();
  const index = records.findIndex((r) => r.participant.id === participantId);
  if (index < 0) return null;

  const current = records[index]!;
  records[index] = {
    ...current,
    participant: { ...current.participant, ...patch, id: participantId },
  };
  writeAllRecords(records);
  return records[index]!.participant;
}

export function markChecklistItem(
  participantId: string,
  itemId: string,
  completed: boolean,
): FounderTestChecklistItem[] | null {
  const records = readAllRecords();
  const index = records.findIndex((r) => r.participant.id === participantId);
  if (index < 0) return null;

  const now = new Date().toISOString();
  const current = records[index]!;
  const checklist = current.checklist.map((item) =>
    item.id === itemId
      ? {
          ...item,
          completed,
          completedAt: completed ? now : undefined,
        }
      : item,
  );

  records[index] = {
    ...current,
    checklist,
    session: { ...current.session, updatedAt: now },
  };
  writeAllRecords(records);
  return checklist;
}

export function clearFounderTestSessions(): void {
  getStorage()?.removeItem(FOUNDER_TEST_STORAGE_KEY);
}

export function clearFounderTestSessionsForEval(): void {
  clearFounderTestSessions();
}
