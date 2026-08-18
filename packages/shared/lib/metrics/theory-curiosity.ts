import { trackLocalEvent } from "@/lib/local-analytics";
import { getStoredEntryCount } from "@/lib/storage";
import type {
  TheoryCuriosityAnswer,
  TheoryCuriosityRecord,
  TheoryCuriosityReport,
} from "@/types/personal-theory";

export const THEORY_CURIOSITY_STORAGE_KEY = "voicememory_theory_curiosity";
export const THEORY_CURIOSITY_EVENT = "theory_curiosity_open";

export const THEORY_CURIOSITY_QUESTION =
  "Before opening ArchiveMe, were you curious whether it had changed its view of you?";

export const THEORY_CURIOSITY_LABELS: Record<TheoryCuriosityAnswer, string> = {
  yes: "Yes",
  maybe: "Maybe",
  no: "No",
};

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `tc-${Date.now()}`;
}

function readAll(): TheoryCuriosityRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(THEORY_CURIOSITY_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as TheoryCuriosityRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: TheoryCuriosityRecord[]): void {
  getStorage()?.setItem(
    THEORY_CURIOSITY_STORAGE_KEY,
    JSON.stringify(records.slice(-400)),
  );
}

export function readTheoryCuriosityRecords(): TheoryCuriosityRecord[] {
  return readAll();
}

export function clearTheoryCuriosityForEval(): void {
  getStorage()?.removeItem(THEORY_CURIOSITY_STORAGE_KEY);
}

export function shouldAskTheoryCuriosity(minReflections = 3): boolean {
  if (getStoredEntryCount() < minReflections) return false;
  const records = readAll();
  if (records.length === 0) return true;
  const last = records[records.length - 1]!;
  const daysSince =
    (Date.now() - new Date(last.at).getTime()) / (1000 * 60 * 60 * 24);
  return daysSince >= 7;
}

export function saveTheoryCuriosityAnswer(answer: TheoryCuriosityAnswer): TheoryCuriosityRecord {
  const record: TheoryCuriosityRecord = {
    id: newId(),
    answer,
    at: new Date().toISOString(),
    reflectionCount: getStoredEntryCount(),
  };
  writeAll([...readAll(), record]);
  trackLocalEvent(THEORY_CURIOSITY_EVENT, { answer });
  return record;
}

export function buildTheoryCuriosityReport(
  records = readAll(),
): TheoryCuriosityReport {
  const yesCount = records.filter((r) => r.answer === "yes").length;
  const maybeCount = records.filter((r) => r.answer === "maybe").length;
  const noCount = records.filter((r) => r.answer === "no").length;
  const total = records.length;
  const curious = yesCount + maybeCount;
  return {
    generatedAt: new Date().toISOString(),
    totalResponses: total,
    yesCount,
    maybeCount,
    noCount,
    theoryCuriosityRate: total > 0 ? Math.round((curious / total) * 100) : 0,
  };
}
