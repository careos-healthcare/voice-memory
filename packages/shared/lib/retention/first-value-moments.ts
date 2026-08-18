import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { trackLocalEvent } from "@/lib/local-analytics";
import type {
  FirstValueMomentKind,
  FirstValueMomentRecord,
  FirstValueSnapshot,
} from "@/types/retention-discovery";

const STORAGE_KEY = "voicememory_first_value_moments";
const FIRST_VISIT_KEY = "voicememory_first_value_first_visit";

const MOMENT_PRIORITY: FirstValueMomentKind[] = [
  "blind_spot_viewed",
  "emerging_pattern_viewed",
  "prediction_review_viewed",
  "breakthrough_captured",
  "second_session_reached",
];

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readMoments(): FirstValueMomentRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as FirstValueMomentRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeMoments(moments: FirstValueMomentRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(moments));
}

function ensureFirstVisitAt(): string {
  const store = getStorage();
  if (!store) return new Date().toISOString();
  let at = store.getItem(FIRST_VISIT_KEY);
  if (!at) {
    at = new Date().toISOString();
    store.setItem(FIRST_VISIT_KEY, at);
  }
  return at;
}

/** Record first occurrence of a value moment (idempotent per kind). */
export function observeFirstValueMoment(kind: FirstValueMomentKind): FirstValueMomentRecord | null {
  const store = getStorage();
  if (!store) return null;

  const firstVisitAt = ensureFirstVisitAt();
  const moments = readMoments();
  if (moments.some((m) => m.kind === kind)) return null;

  const daysSinceFirstVisit = Math.max(
    0,
    daysBetweenKeys(toDayKey(firstVisitAt), toDayKey(new Date().toISOString())),
  );

  const record: FirstValueMomentRecord = {
    kind,
    at: new Date().toISOString(),
    daysSinceFirstVisit,
  };
  moments.push(record);
  writeMoments(moments);

  trackLocalEvent("first_value_moment", {
    kind,
    daysSinceFirstVisit: String(daysSinceFirstVisit),
  });

  return record;
}

export function readFirstValueSnapshot(): FirstValueSnapshot {
  const firstVisitAt = getStorage()?.getItem(FIRST_VISIT_KEY) ?? null;
  const moments = readMoments();

  let timeToFirstValueKind: FirstValueMomentKind | null = null;
  let timeToFirstValueDays: number | null = null;

  for (const kind of MOMENT_PRIORITY) {
    const hit = moments.find((m) => m.kind === kind);
    if (hit) {
      timeToFirstValueKind = kind;
      timeToFirstValueDays = hit.daysSinceFirstVisit;
      break;
    }
  }

  if (timeToFirstValueDays === null && moments.length > 0) {
    const earliest = [...moments].sort((a, b) => a.daysSinceFirstVisit - b.daysSinceFirstVisit)[0]!;
    timeToFirstValueKind = earliest.kind;
    timeToFirstValueDays = earliest.daysSinceFirstVisit;
  }

  return {
    firstVisitAt,
    moments,
    timeToFirstValueDays,
    timeToFirstValueKind,
  };
}

export function clearFirstValueMomentsForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(STORAGE_KEY);
  store.removeItem(FIRST_VISIT_KEY);
}
