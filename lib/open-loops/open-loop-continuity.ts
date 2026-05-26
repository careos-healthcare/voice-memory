import { detectEmotionalShift, moodLabelIfConfident } from "@/lib/open-loops/emotional-shift";
import { readPrimaryAnchorPhrase } from "@/lib/open-loops/open-loop-storage";
import { getEntry, getMemoryEligibleEntries } from "@/lib/storage";
import type { OpenLoop, OpenLoopConnectedMoment } from "@/types/open-loop";
import type { JournalEntry } from "@/types/journal";

const MAX_MOMENTS = 5;
const QUOTE_MAX = 100;

function quoteFragment(entry: JournalEntry, anchors: string[]): string {
  for (const anchor of anchors) {
    if (entry.transcript.includes(anchor)) {
      const trimmed = anchor.trim();
      return trimmed.length > QUOTE_MAX ? `${trimmed.slice(0, QUOTE_MAX - 1)}…` : trimmed;
    }
  }
  const fromTranscript = entry.transcript.trim().split(/(?<=[.!?])\s+/)[0] ?? "";
  if (fromTranscript.length >= 12) {
    return fromTranscript.length > QUOTE_MAX
      ? `${fromTranscript.slice(0, QUOTE_MAX - 1)}…`
      : fromTranscript;
  }
  const observation = entry.reflection.concreteObservation?.trim();
  if (observation && observation.length >= 12) {
    return observation.length > QUOTE_MAX
      ? `${observation.slice(0, QUOTE_MAX - 1)}…`
      : observation;
  }
  return "";
}

function pickStrongestAnchor(anchors: string[]): string {
  if (anchors.length === 0) return "";
  return [...anchors].sort((a, b) => b.length - a.length)[0]?.trim() ?? anchors[0];
}

function relatedEntries(loop: OpenLoop, pool: JournalEntry[]): JournalEntry[] {
  const ids = new Set(loop.relatedEntryIds);
  return pool
    .filter((entry) => ids.has(entry.id))
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

export function buildConnectedMoments(
  loop: OpenLoop,
  entries: JournalEntry[],
): OpenLoopConnectedMoment[] {
  const related = relatedEntries(loop, entries);
  const moments: OpenLoopConnectedMoment[] = [];

  for (const entry of related) {
    const fragment = quoteFragment(entry, loop.anchorPhrases);
    if (!fragment) continue;
    moments.push({
      entryId: entry.id,
      recordedAt: entry.createdAt,
      quoteFragment: fragment,
      emotionalLabel: moodLabelIfConfident(entry),
    });
  }

  return moments.slice(-MAX_MOMENTS);
}

export function refreshOpenLoopContinuity(
  loop: OpenLoop,
  entries = getMemoryEligibleEntries(),
): OpenLoop {
  const related = relatedEntries(loop, entries);
  const connectedMoments = buildConnectedMoments(loop, entries);
  const recurrenceCount = Math.max(1, related.length);
  const strongestAnchorPhrase =
    pickStrongestAnchor(loop.anchorPhrases) || readPrimaryAnchorPhrase(loop);

  const shift = detectEmotionalShift(related, loop.anchorPhrases);

  const mentionHistory = [...(loop.mentionHistory ?? [])];
  for (const entry of related) {
    if (!mentionHistory.includes(entry.createdAt)) {
      mentionHistory.push(entry.createdAt);
    }
  }
  mentionHistory.sort(
    (a, b) => new Date(a).getTime() - new Date(b).getTime(),
  );

  const firstSeenAt =
    mentionHistory[0] ??
    getEntry(loop.sourceEntryId)?.createdAt ??
    loop.firstSeenAt ??
    loop.createdAt;

  return {
    ...loop,
    firstSeenAt,
    recurrenceCount,
    strongestAnchorPhrase,
    connectedMoments,
    mentionHistory,
    emotionalShiftSummary:
      shift.confidence === "high" ? shift.shift : loop.emotionalShiftSummary,
    lastMentionedAt:
      mentionHistory[mentionHistory.length - 1] ?? loop.lastMentionedAt,
  };
}

export function refreshAllOpenLoopContinuity(loops: OpenLoop[]): OpenLoop[] {
  const entries = getMemoryEligibleEntries();
  return loops.map((loop) => refreshOpenLoopContinuity(loop, entries));
}
