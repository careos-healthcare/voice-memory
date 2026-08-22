import type {
  InsightOutcomeEvent,
  InsightOutcomeResponse,
  InsightOutcomeTrigger,
} from "@/types/insight-outcome";

export const INSIGHT_OUTCOME_EVENTS_KEY = "voicememory_insight_outcome_events";
export const INSIGHT_OUTCOME_PENDING_KEY = "voicememory_insight_outcome_pending";
export const INSIGHT_OUTCOME_LAST_SHOWN_KEY = "voicememory_insight_outcome_last_shown";

export const OUTCOME_PROMPT_COOLDOWN_MS = 14 * 24 * 60 * 60 * 1000;

const MAX_EVENTS = 400;

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
  return `io-${Date.now()}`;
}

function normalize(raw: unknown): InsightOutcomeEvent | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.id !== "string" || typeof row.insightId !== "string") return null;
  if (row.insightType !== "blind_spot" && row.insightType !== "theory") return null;
  if (typeof row.createdAt !== "string") return null;

  return {
    id: row.id,
    insightId: row.insightId,
    insightType: row.insightType,
    scorecardScore: typeof row.scorecardScore === "number" ? row.scorecardScore : 0,
    contradictionPresent: Boolean(row.contradictionPresent),
    costEvidencePresent: Boolean(row.costEvidencePresent),
    crossLifeAreaPresent: Boolean(row.crossLifeAreaPresent),
    failedPredictionPresent: Boolean(row.failedPredictionPresent),
    longSpanPresent: Boolean(row.longSpanPresent),
    createdAt: row.createdAt,
    evidenceStrength: row.evidenceStrength as InsightOutcomeEvent["evidenceStrength"],
    confidenceLabel:
      typeof row.confidenceLabel === "string" ? row.confidenceLabel : undefined,
    patternType: typeof row.patternType === "string" ? row.patternType : undefined,
    theoryType: typeof row.theoryType === "string" ? row.theoryType : undefined,
    trigger: row.trigger as InsightOutcomeTrigger | undefined,
    outcome: row.outcome as InsightOutcomeResponse | undefined,
    respondedAt: typeof row.respondedAt === "string" ? row.respondedAt : undefined,
  };
}

export function readAllInsightOutcomeEvents(): InsightOutcomeEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(INSIGHT_OUTCOME_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((e): e is InsightOutcomeEvent => Boolean(e))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  } catch {
    return [];
  }
}

function writeAll(events: InsightOutcomeEvent[]): void {
  getStorage()?.setItem(
    INSIGHT_OUTCOME_EVENTS_KEY,
    JSON.stringify(events.slice(0, MAX_EVENTS)),
  );
}

export function readInsightOutcomeEventsWithResponse(): InsightOutcomeEvent[] {
  return readAllInsightOutcomeEvents().filter((e) => Boolean(e.outcome && e.respondedAt));
}

export function canShowInsightOutcomePrompt(now = Date.now()): boolean {
  const store = getStorage();
  if (!store) return false;
  const last = store.getItem(INSIGHT_OUTCOME_LAST_SHOWN_KEY);
  if (!last) return true;
  return now - new Date(last).getTime() >= OUTCOME_PROMPT_COOLDOWN_MS;
}

export function markInsightOutcomePromptShown(): void {
  getStorage()?.setItem(INSIGHT_OUTCOME_LAST_SHOWN_KEY, new Date().toISOString());
}

export interface PendingInsightOutcomeOffer {
  draft: Omit<InsightOutcomeEvent, "id" | "createdAt" | "outcome" | "respondedAt">;
  trigger: InsightOutcomeTrigger;
  queuedAt: string;
}

export function getPendingInsightOutcomeOffer(): PendingInsightOutcomeOffer | null {
  const store = getStorage();
  if (!store) return null;
  try {
    const raw = store.getItem(INSIGHT_OUTCOME_PENDING_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as PendingInsightOutcomeOffer;
    if (!parsed?.draft || !parsed.trigger) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function scheduleInsightOutcomeOffer(
  draft: PendingInsightOutcomeOffer["draft"],
  trigger: InsightOutcomeTrigger,
): boolean {
  if (!canShowInsightOutcomePrompt()) return false;
  getStorage()?.setItem(
    INSIGHT_OUTCOME_PENDING_KEY,
    JSON.stringify({
      draft,
      trigger,
      queuedAt: new Date().toISOString(),
    } satisfies PendingInsightOutcomeOffer),
  );
  return true;
}

export function clearPendingInsightOutcomeOffer(): void {
  getStorage()?.removeItem(INSIGHT_OUTCOME_PENDING_KEY);
}

export function saveInsightOutcomeResponse(
  outcome: InsightOutcomeResponse,
  pending?: PendingInsightOutcomeOffer | null,
): InsightOutcomeEvent | null {
  const offer = pending ?? getPendingInsightOutcomeOffer();
  if (!offer) return null;

  const respondedAt = new Date().toISOString();
  const record: InsightOutcomeEvent = {
    ...offer.draft,
    id: newId(),
    createdAt: offer.queuedAt,
    trigger: offer.trigger,
    outcome,
    respondedAt,
  };

  const all = readAllInsightOutcomeEvents();
  all.unshift(record);
  writeAll(all);
  clearPendingInsightOutcomeOffer();
  markInsightOutcomePromptShown();
  return record;
}

export function dismissInsightOutcomePrompt(): void {
  clearPendingInsightOutcomeOffer();
  markInsightOutcomePromptShown();
}

export function clearInsightOutcomeForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(INSIGHT_OUTCOME_EVENTS_KEY);
  store.removeItem(INSIGHT_OUTCOME_PENDING_KEY);
  store.removeItem(INSIGHT_OUTCOME_LAST_SHOWN_KEY);
}
