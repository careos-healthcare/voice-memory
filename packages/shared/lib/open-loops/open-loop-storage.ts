import { hasUnresolvedThreadLanguage } from "@/lib/open-loops/unresolved-signals";
import {
  refreshAllOpenLoopContinuity,
  refreshOpenLoopContinuity,
} from "@/lib/open-loops/open-loop-continuity";
import {
  recordContinuityBuildDuration,
  recordStorageRead,
  recordStorageWrite,
} from "@/lib/open-loops/open-loop-performance";
import { assertWriteAllowed } from "@/lib/runtime/render-safe";
import {
  OPEN_LOOP_EVENTS,
  trackOpenLoopClosed,
  trackOpenLoopCreated,
  trackOpenLoopReflectionAfterResurface,
  trackOpenLoopSoftened,
} from "@/lib/open-loops/open-loop-observation";
import { pickOpenLoopResurfacingLine } from "@/lib/open-loops/open-loop-resurfacing-lines";
import { readLocalEvents } from "@/lib/local-analytics";
import { formatEntryDate } from "@/lib/utils";
import { getEntry } from "@/lib/storage";
import type {
  OpenLoop,
  OpenLoopStatus,
  OpenLoopPresentation,
  OpenLoopWithEntryMeta,
} from "@/types/open-loop";

const OPEN_LOOPS_KEY = "voicememory_open_loops";
const PROMPT_DISMISS_PREFIX = "voicememory_open_loop_prompt_dismissed_until:";

export const OPEN_LOOP_CHANGE_EVENT = "voicememory-open-loops-changed";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function normalizeLegacyStatus(status: unknown): OpenLoopStatus {
  if (status === "softened" || status === "closed") return status;
  if (status === "paused") return "softened";
  return "open";
}

function pickStrongestAnchor(anchors: string[], fallback: string): string {
  if (anchors.length === 0) return fallback;
  return [...anchors].sort((a, b) => b.length - a.length)[0]?.trim() ?? fallback;
}

function normalizeLoop(raw: unknown): OpenLoop | null {
  if (!raw || typeof raw !== "object") return null;
  const record = raw as Record<string, unknown>;

  const openLoopId =
    typeof record.openLoopId === "string"
      ? record.openLoopId
      : typeof record.id === "string"
        ? record.id
        : null;
  const sourceEntryId =
    typeof record.sourceEntryId === "string"
      ? record.sourceEntryId
      : typeof record.entryId === "string"
        ? record.entryId
        : null;

  if (!openLoopId || !sourceEntryId) return null;

  const createdAt =
    typeof record.createdAt === "string" ? record.createdAt : new Date().toISOString();
  const updatedAt =
    typeof record.updatedAt === "string" ? record.updatedAt : createdAt;
  const lastMentionedAt =
    typeof record.lastMentionedAt === "string"
      ? record.lastMentionedAt
      : typeof record.lastResurfacedAt === "string"
        ? record.lastResurfacedAt
        : updatedAt;
  const firstSeenAt =
    typeof record.firstSeenAt === "string" ? record.firstSeenAt : createdAt;

  const legacyPhrase =
    typeof record.sourcePhrase === "string" ? record.sourcePhrase.trim() : "";
  const anchorPhrases = Array.isArray(record.anchorPhrases)
    ? record.anchorPhrases.filter((value): value is string => typeof value === "string")
    : legacyPhrase
      ? [legacyPhrase]
      : [];

  const relatedEntryIds = Array.isArray(record.relatedEntryIds)
    ? record.relatedEntryIds.filter((value): value is string => typeof value === "string")
    : Array.isArray(record.linkedEntryIds)
      ? record.linkedEntryIds.filter((value): value is string => typeof value === "string")
      : [sourceEntryId];

  const userNextStep =
    typeof record.userNextStep === "string" ? record.userNextStep.trim() : "";
  if (!userNextStep) return null;

  const mentionHistory = Array.isArray(record.mentionHistory)
    ? record.mentionHistory.filter((value): value is string => typeof value === "string")
    : [firstSeenAt];

  const connectedMoments = Array.isArray(record.connectedMoments)
    ? record.connectedMoments.filter(
        (value): value is OpenLoop["connectedMoments"][number] =>
          Boolean(
            value &&
              typeof value === "object" &&
              typeof (value as OpenLoop["connectedMoments"][number]).entryId === "string" &&
              typeof (value as OpenLoop["connectedMoments"][number]).recordedAt === "string" &&
              typeof (value as OpenLoop["connectedMoments"][number]).quoteFragment === "string",
          ),
      )
    : [];

  const title = typeof record.title === "string" ? record.title : "Open thread";
  const strongestAnchorPhrase =
    typeof record.strongestAnchorPhrase === "string"
      ? record.strongestAnchorPhrase
      : pickStrongestAnchor(anchorPhrases, title);

  const shiftValues = [
    "heavier",
    "softer",
    "unresolved",
    "uncertain",
    "avoided_then_revisited",
  ] as const;
  const emotionalShiftSummary = shiftValues.includes(
    record.emotionalShiftSummary as (typeof shiftValues)[number],
  )
    ? (record.emotionalShiftSummary as OpenLoop["emotionalShiftSummary"])
    : undefined;

  return {
    openLoopId,
    sourceEntryId,
    title,
    userNextStep,
    status: normalizeLegacyStatus(record.status),
    createdAt,
    updatedAt,
    lastMentionedAt,
    firstSeenAt,
    relatedEntryIds: [...new Set([sourceEntryId, ...relatedEntryIds])],
    anchorPhrases,
    concernLabel:
      typeof record.concernLabel === "string" ? record.concernLabel : undefined,
    recurrenceCount:
      typeof record.recurrenceCount === "number" && record.recurrenceCount > 0
        ? Math.round(record.recurrenceCount)
        : 1,
    strongestAnchorPhrase,
    emotionalShiftSummary,
    connectedMoments,
    mentionHistory: [...new Set(mentionHistory)].sort(
      (a, b) => new Date(a).getTime() - new Date(b).getTime(),
    ),
    closureNote:
      typeof record.closureNote === "string" ? record.closureNote : undefined,
    closedAt: typeof record.closedAt === "string" ? record.closedAt : undefined,
  };
}

let loopsReadCache: OpenLoop[] | null = null;

function invalidateLoopsReadCache(): void {
  loopsReadCache = null;
}

function readLoops(): OpenLoop[] {
  if (!isBrowser()) return [];
  if (loopsReadCache) return loopsReadCache;

  try {
    recordStorageRead();
    const raw = localStorage.getItem(OPEN_LOOPS_KEY);
    if (!raw) {
      loopsReadCache = [];
      return loopsReadCache;
    }
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) {
      loopsReadCache = [];
      return loopsReadCache;
    }
    loopsReadCache = parsed
      .map(normalizeLoop)
      .filter((loop): loop is OpenLoop => loop !== null);
    return loopsReadCache;
  } catch {
    loopsReadCache = [];
    return loopsReadCache;
  }
}

function writeLoops(loops: OpenLoop[]): void {
  if (!isBrowser()) return;
  assertWriteAllowed("open-loop-storage:writeLoops");
  recordStorageWrite();
  localStorage.setItem(OPEN_LOOPS_KEY, JSON.stringify(loops));
  invalidateLoopsReadCache();
}

function dispatchChange(): void {
  if (!isBrowser()) return;
  window.dispatchEvent(new CustomEvent(OPEN_LOOP_CHANGE_EVENT));
}

function sortLoops(loops: OpenLoop[]): OpenLoop[] {
  return [...loops].sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
  );
}

function withFreshContinuity(loops: OpenLoop[]): OpenLoop[] {
  const started = typeof performance !== "undefined" ? performance.now() : 0;
  const refreshed = refreshAllOpenLoopContinuity(loops);
  if (started > 0) {
    recordContinuityBuildDuration(performance.now() - started);
  }
  return refreshed;
}

/** Deferred job target — refreshes continuity and persists. */
export function persistRefreshedOpenLoopContinuity(): void {
  if (!isBrowser()) return;
  const stored = readLoops();
  writeLoops(withFreshContinuity(stored));
  dispatchChange();
}

export function readAllOpenLoopsFromStore(): OpenLoop[] {
  return sortLoops(readLoops());
}

export function readActiveOpenLoopsFromStore(): OpenLoop[] {
  return readAllOpenLoopsFromStore().filter(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
}

/** @deprecated Use readAllOpenLoops from @/lib/runtime/read-model */
export function getAllOpenLoops(): OpenLoop[] {
  return readAllOpenLoopsFromStore();
}

/** @deprecated Use readActiveOpenLoops from @/lib/runtime/read-model */
export function getActiveOpenLoops(): OpenLoop[] {
  return readActiveOpenLoopsFromStore();
}

export function readOpenLoopByIdFromStore(openLoopId: string): OpenLoop | null {
  return readAllOpenLoopsFromStore().find((loop) => loop.openLoopId === openLoopId) ?? null;
}

/** @deprecated Use readOpenLoopById from @/lib/runtime/read-model */
export function getOpenLoopById(openLoopId: string): OpenLoop | null {
  return readOpenLoopByIdFromStore(openLoopId);
}

export function readOpenLoopsForEntryFromStore(entryId: string): OpenLoop[] {
  return readAllOpenLoopsFromStore().filter(
    (loop) =>
      loop.sourceEntryId === entryId || loop.relatedEntryIds.includes(entryId),
  );
}

/** @deprecated Use readOpenLoopsForEntry from @/lib/runtime/read-model */
export function getOpenLoopsForEntry(entryId: string): OpenLoop[] {
  return readOpenLoopsForEntryFromStore(entryId);
}

export function readHasActiveOpenLoopForEntry(entryId: string): boolean {
  return readOpenLoopsForEntryFromStore(entryId).some(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
}

/** @deprecated Use readHasActiveOpenLoop from @/lib/runtime/read-model */
export function hasActiveOpenLoopForEntry(entryId: string): boolean {
  return readHasActiveOpenLoopForEntry(entryId);
}

export function dismissOpenLoopPromptInStore(
  entryId: string,
  dismissMs = 48 * 60 * 60 * 1000,
): void {
  if (!isBrowser()) return;
  assertWriteAllowed("open-loop-storage:dismissOpenLoopPrompt");
  recordStorageWrite();
  const until = Date.now() + dismissMs;
  localStorage.setItem(`${PROMPT_DISMISS_PREFIX}${entryId}`, String(until));
}

/** @deprecated Use writeDismissOpenLoopPrompt from @/lib/runtime/write-actions */
export function dismissOpenLoopPrompt(entryId: string, dismissMs?: number): void {
  dismissOpenLoopPromptInStore(entryId, dismissMs);
}

export function readIsOpenLoopPromptDismissed(entryId: string): boolean {
  if (!isBrowser()) return false;
  recordStorageRead();
  const raw = localStorage.getItem(`${PROMPT_DISMISS_PREFIX}${entryId}`);
  if (!raw) return false;
  const until = Number(raw);
  if (!Number.isFinite(until)) return true;
  return Date.now() < until;
}

/** @deprecated Use readOpenLoopPromptDismissed from @/lib/runtime/read-model */
export function isOpenLoopPromptDismissed(entryId: string): boolean {
  return readIsOpenLoopPromptDismissed(entryId);
}

export function readShouldShowOpenLoopPrompt(
  entryId: string,
  transcript: string,
  options?: { isRevisit?: boolean },
): boolean {
  if (!transcript.trim()) return false;
  if (readIsOpenLoopPromptDismissed(entryId)) return false;
  if (readHasActiveOpenLoopForEntry(entryId)) return false;
  if (!hasUnresolvedThreadLanguage(transcript)) return false;
  if (options?.isRevisit) return true;
  return true;
}

/** @deprecated Use writeCreateOpenLoop from @/lib/runtime/write-actions */
export function createOpenLoop(input: Parameters<typeof createOpenLoopInStore>[0]): OpenLoop {
  return createOpenLoopInStore(input);
}

export function createOpenLoopInStore(input: {
  sourceEntryId: string;
  title: string;
  userNextStep: string;
  anchorPhrases: string[];
  concernLabel?: string;
}): OpenLoop {
  const now = new Date().toISOString();
  const strongestAnchorPhrase = pickStrongestAnchor(input.anchorPhrases, input.title);
  const base: OpenLoop = {
    openLoopId: crypto.randomUUID(),
    sourceEntryId: input.sourceEntryId,
    createdAt: now,
    updatedAt: now,
    lastMentionedAt: now,
    firstSeenAt: now,
    title: input.title.trim() || "Open thread",
    userNextStep: input.userNextStep.trim(),
    status: "open",
    relatedEntryIds: [input.sourceEntryId],
    anchorPhrases: input.anchorPhrases.filter(Boolean),
    concernLabel: input.concernLabel,
    recurrenceCount: 1,
    strongestAnchorPhrase,
    connectedMoments: [],
    mentionHistory: [now],
  };

  const next = refreshOpenLoopContinuity(base);

  const loops = readLoops().filter(
    (loop) =>
      !(
        loop.sourceEntryId === input.sourceEntryId &&
        loop.status !== "closed"
      ),
  );
  writeLoops([next, ...loops]);
  dispatchChange();
  trackOpenLoopCreated(next.openLoopId, next.sourceEntryId);
  void import("@/lib/sync/schedule").then((mod) => mod.scheduleEncryptedSync());
  return next;
}

/** @deprecated Use writeUpdateOpenLoopStatus from @/lib/runtime/write-actions */
export function updateOpenLoopStatus(
  openLoopId: string,
  status: OpenLoopStatus,
): OpenLoop | null {
  return updateOpenLoopStatusInStore(openLoopId, status);
}

export function updateOpenLoopStatusInStore(
  openLoopId: string,
  status: OpenLoopStatus,
): OpenLoop | null {
  const loops = readLoops();
  const index = loops.findIndex((loop) => loop.openLoopId === openLoopId);
  if (index < 0) return null;

  const now = new Date().toISOString();
  const updated = refreshOpenLoopContinuity({
    ...loops[index],
    status,
    updatedAt: now,
    lastMentionedAt: now,
  });
  loops[index] = updated;
  writeLoops(loops);
  dispatchChange();
  if (status === "softened") trackOpenLoopSoftened(openLoopId);
  return updated;
}

/** @deprecated Use writeCloseOpenLoop from @/lib/runtime/write-actions */
export function closeOpenLoop(openLoopId: string, closureNote?: string): OpenLoop | null {
  return closeOpenLoopInStore(openLoopId, closureNote);
}

export function closeOpenLoopInStore(
  openLoopId: string,
  closureNote?: string,
): OpenLoop | null {
  const loops = readLoops();
  const index = loops.findIndex((loop) => loop.openLoopId === openLoopId);
  if (index < 0) return null;

  const now = new Date().toISOString();
  const trimmedNote = closureNote?.trim();
  const updated = refreshOpenLoopContinuity({
    ...loops[index],
    status: "closed",
    updatedAt: now,
    lastMentionedAt: now,
    closedAt: now,
    closureNote: trimmedNote || undefined,
  });
  loops[index] = updated;
  writeLoops(loops);
  dispatchChange();
  trackOpenLoopClosed(openLoopId);
  return updated;
}

/** @deprecated Use writeTouchOpenLoopRelatedEntry from @/lib/runtime/write-actions */
export function touchRelatedEntry(openLoopId: string, entryId: string): OpenLoop | null {
  return touchRelatedEntryInStore(openLoopId, entryId);
}

export function touchRelatedEntryInStore(openLoopId: string, entryId: string): OpenLoop | null {
  const loops = readLoops();
  const index = loops.findIndex((loop) => loop.openLoopId === openLoopId);
  if (index < 0) return null;

  const related = new Set(loops[index].relatedEntryIds);
  related.add(entryId);
  const entry = getEntry(entryId);
  const mentionAt = entry?.createdAt ?? new Date().toISOString();
  const now = new Date().toISOString();
  const history = [...loops[index].mentionHistory];
  if (!history.includes(mentionAt)) history.push(mentionAt);

  const updated = refreshOpenLoopContinuity({
    ...loops[index],
    relatedEntryIds: [...related],
    mentionHistory: history,
    updatedAt: now,
    lastMentionedAt: mentionAt,
  });
  loops[index] = updated;
  writeLoops(loops);
  dispatchChange();
  return updated;
}

/** @deprecated Use writeRecordOpenLoopMentioned from @/lib/runtime/write-actions */
export function recordOpenLoopMentioned(openLoopId: string): void {
  recordOpenLoopMentionedInStore(openLoopId);
}

export function recordOpenLoopMentionedInStore(openLoopId: string): void {
  const loops = readLoops();
  const index = loops.findIndex((loop) => loop.openLoopId === openLoopId);
  if (index < 0) return;

  const now = new Date().toISOString();
  const history = [...loops[index].mentionHistory];
  if (!history.includes(now)) history.push(now);

  loops[index] = refreshOpenLoopContinuity({
    ...loops[index],
    mentionHistory: history,
    lastMentionedAt: now,
    updatedAt: now,
  });
  writeLoops(loops);
  dispatchChange();
}

/** @deprecated Use writeRemoveOpenLoopsForEntry from @/lib/runtime/write-actions */
export function removeOpenLoopsForEntry(entryId: string): void {
  removeOpenLoopsForEntryInStore(entryId);
}

export function removeOpenLoopsForEntryInStore(entryId: string): void {
  const next = readLoops().filter((loop) => loop.sourceEntryId !== entryId);
  if (next.length === readLoops().length) return;
  writeLoops(next);
  dispatchChange();
}

export function attachEntryMeta(loop: OpenLoop): OpenLoopWithEntryMeta {
  const entry = getEntry(loop.sourceEntryId);
  const createdAt = entry?.createdAt ?? null;
  return {
    ...loop,
    sourceEntryCreatedAt: createdAt,
    sourceEntryDateLabel: createdAt ? formatEntryDate(createdAt) : null,
  };
}

export function readOpenLoopPresentationFromStore(loop: OpenLoop): OpenLoopPresentation {
  const meta = attachEntryMeta(loop);
  return {
    ...meta,
    resurfacingLine: pickOpenLoopResurfacingLine(loop),
  };
}

/** @deprecated Use readOpenLoopPresentation from @/lib/runtime/read-model */
export function buildOpenLoopPresentation(loop: OpenLoop): OpenLoopPresentation {
  return readOpenLoopPresentationFromStore(loop);
}

export function readOpenLoopsWithMetaFromStore(activeOnly = true): OpenLoopWithEntryMeta[] {
  const loops = activeOnly ? readActiveOpenLoopsFromStore() : readAllOpenLoopsFromStore();
  return loops.map(attachEntryMeta);
}

/** @deprecated Use readOpenLoopsWithMeta from @/lib/runtime/read-model */
export function listOpenLoopsWithMeta(activeOnly = true): OpenLoopWithEntryMeta[] {
  return readOpenLoopsWithMetaFromStore(activeOnly);
}

/** @deprecated Use readOpenLoopPresentations from @/lib/runtime/read-model */
export function listOpenLoopPresentations(activeOnly = true): OpenLoopPresentation[] {
  const loops = activeOnly ? readActiveOpenLoopsFromStore() : readAllOpenLoopsFromStore();
  return loops.map(readOpenLoopPresentationFromStore);
}

/** Primary anchor phrase for display — never generated advice. */
export function readPrimaryAnchorPhrase(loop: OpenLoop): string {
  return loop.strongestAnchorPhrase?.trim() || loop.anchorPhrases[0]?.trim() || loop.title;
}

/** @deprecated Use readOpenLoopAnchorPhrase from @/lib/runtime/read-model */
export function primaryAnchorPhrase(loop: OpenLoop): string {
  return readPrimaryAnchorPhrase(loop);
}

/** Link new reflections to active loops — write/deferred only. */
export function maybeLinkReflectionAfterOpenLoopResurface(entry: {
  id: string;
  createdAt: string;
  transcript: string;
}): void {
  if (!entry.transcript.trim()) return;
  assertWriteAllowed("open-loop-storage:maybeLinkReflectionAfterOpenLoopResurface");

  const events = readLocalEvents();
  const loops = readActiveOpenLoopsFromStore();

  for (const loop of loops) {
    if (loop.sourceEntryId === entry.id) continue;
    if (new Date(entry.createdAt).getTime() <= new Date(loop.firstSeenAt).getTime()) continue;

    const resurfaceEvents = events.filter(
      (event) =>
        event.name === OPEN_LOOP_EVENTS.resurfacingShown &&
        event.meta?.openLoopId === loop.openLoopId,
    );
    const lastResurfaceAt = resurfaceEvents.sort(
      (a, b) => new Date(b.at).getTime() - new Date(a.at).getTime(),
    )[0]?.at;
    const resurfaceMs = lastResurfaceAt
      ? new Date(lastResurfaceAt).getTime()
      : new Date(loop.lastMentionedAt).getTime();
    const hoursSinceResurface = (Date.now() - resurfaceMs) / (1000 * 60 * 60);

    const matchesAnchor = loop.anchorPhrases.some((phrase) => {
      const fragment = phrase.trim().slice(0, 24);
      return fragment.length >= 10 && entry.transcript.includes(fragment);
    });
    const withinReturnWindow =
      hoursSinceResurface >= 0 && hoursSinceResurface <= 96 && resurfaceEvents.length > 0;

    if (!matchesAnchor && !withinReturnWindow && loop.recurrenceCount < 2) continue;

    touchRelatedEntry(loop.openLoopId, entry.id);
    if (withinReturnWindow || matchesAnchor) {
      trackOpenLoopReflectionAfterResurface(loop.openLoopId, entry.id);
    }
  }
}

export function readEntryOpenLoopContinuityLineFromStore(entryId: string): string | null {
  const loops = readOpenLoopsForEntryFromStore(entryId).filter(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
  if (loops.length === 0) return null;
  return pickOpenLoopResurfacingLine(loops[0]);
}

/** @deprecated Use readEntryOpenLoopContinuityLine from @/lib/runtime/read-model */
export function pickEntryOpenLoopContinuityLine(entryId: string): string | null {
  return readEntryOpenLoopContinuityLineFromStore(entryId);
}

export { enqueueRefreshOpenLoopContinuity as scheduleOpenLoopContinuityRefresh } from "@/lib/runtime/deferred-jobs";
