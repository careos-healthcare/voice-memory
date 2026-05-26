import { hasUnresolvedThreadLanguage } from "@/lib/open-loops/unresolved-signals";
import {
  refreshAllOpenLoopContinuity,
  refreshOpenLoopContinuity,
} from "@/lib/open-loops/open-loop-continuity";
import { pickOpenLoopResurfacingLine } from "@/lib/open-loops/open-loop-resurfacing-lines";
import { formatEntryDate } from "@/lib/utils";
import { getEntry } from "@/lib/storage";
import type {
  OpenLoop,
  OpenLoopStatus,
  OpenLoopPresentation,
  OpenLoopWithEntryMeta,
} from "@/types/open-loop";

const OPEN_LOOPS_KEY = "voicememory_open_loops";
const PROMPT_DISMISS_PREFIX = "voicememory_open_loop_prompt_dismissed:";

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

function readLoops(): OpenLoop[] {
  if (!isBrowser()) return [];

  try {
    const raw = localStorage.getItem(OPEN_LOOPS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalizeLoop)
      .filter((loop): loop is OpenLoop => loop !== null);
  } catch {
    return [];
  }
}

function writeLoops(loops: OpenLoop[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(OPEN_LOOPS_KEY, JSON.stringify(loops));
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
  return refreshAllOpenLoopContinuity(loops);
}

export function getAllOpenLoops(): OpenLoop[] {
  return sortLoops(withFreshContinuity(readLoops()));
}

export function getActiveOpenLoops(): OpenLoop[] {
  return getAllOpenLoops().filter(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
}

export function getOpenLoopById(openLoopId: string): OpenLoop | null {
  return getAllOpenLoops().find((loop) => loop.openLoopId === openLoopId) ?? null;
}

export function getOpenLoopsForEntry(entryId: string): OpenLoop[] {
  return getAllOpenLoops().filter(
    (loop) =>
      loop.sourceEntryId === entryId || loop.relatedEntryIds.includes(entryId),
  );
}

export function hasActiveOpenLoopForEntry(entryId: string): boolean {
  return getOpenLoopsForEntry(entryId).some(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
}

export function dismissOpenLoopPrompt(entryId: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(`${PROMPT_DISMISS_PREFIX}${entryId}`, "1");
}

export function isOpenLoopPromptDismissed(entryId: string): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(`${PROMPT_DISMISS_PREFIX}${entryId}`) === "1";
}

export function shouldShowOpenLoopPrompt(
  entryId: string,
  transcript: string,
  options?: { isRevisit?: boolean },
): boolean {
  void options?.isRevisit;
  if (!transcript.trim()) return false;
  if (isOpenLoopPromptDismissed(entryId)) return false;
  if (hasActiveOpenLoopForEntry(entryId)) return false;
  return hasUnresolvedThreadLanguage(transcript);
}

export function createOpenLoop(input: {
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
  void import("@/lib/sync/schedule").then((mod) => mod.scheduleEncryptedSync());
  return next;
}

export function updateOpenLoopStatus(
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
  return updated;
}

export function closeOpenLoop(
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
  return updated;
}

export function touchRelatedEntry(openLoopId: string, entryId: string): OpenLoop | null {
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

export function recordOpenLoopMentioned(openLoopId: string): void {
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

export function removeOpenLoopsForEntry(entryId: string): void {
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

export function buildOpenLoopPresentation(loop: OpenLoop): OpenLoopPresentation {
  const meta = attachEntryMeta(loop);
  return {
    ...meta,
    resurfacingLine: pickOpenLoopResurfacingLine(loop),
  };
}

export function listOpenLoopsWithMeta(activeOnly = true): OpenLoopWithEntryMeta[] {
  const loops = activeOnly ? getActiveOpenLoops() : getAllOpenLoops();
  return loops.map(attachEntryMeta);
}

export function listOpenLoopPresentations(activeOnly = true): OpenLoopPresentation[] {
  const loops = activeOnly ? getActiveOpenLoops() : getAllOpenLoops();
  return loops.map(buildOpenLoopPresentation);
}

/** Primary anchor phrase for display — never generated advice. */
export function primaryAnchorPhrase(loop: OpenLoop): string {
  return loop.strongestAnchorPhrase?.trim() || loop.anchorPhrases[0]?.trim() || loop.title;
}

/** One continuity line for an entry view — max one loop, one line. */
export function pickEntryOpenLoopContinuityLine(entryId: string): string | null {
  const loops = getOpenLoopsForEntry(entryId).filter(
    (loop) => loop.status === "open" || loop.status === "softened",
  );
  if (loops.length === 0) return null;

  const refreshed = refreshOpenLoopContinuity(loops[0]);
  return pickOpenLoopResurfacingLine(refreshed);
}
