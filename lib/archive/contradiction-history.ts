import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { ARCHIVE_EMOTIONAL, toArchiveEmotionalCopy } from "@/lib/archive/archive-emotional-copy";
import { buildBeliefChangeTimeline } from "@/lib/archive/belief-timeline";
import {
  periodKeyFromIso,
  readBeliefTimelineHistory,
} from "@/lib/archive/belief-timeline-storage";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ContradictionHistoryView } from "@/types/contradiction-history";
import type { BeliefTimelinePoint } from "@/types/belief-timeline";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const CONTRADICTION_HISTORY_TITLE = "Contradiction history";
export const CONTRADICTION_HISTORY_HEADLINE =
  "Your archive has changed its mind before.";

const MIN_CONFIDENCE_SWING = 5;
const MIN_SPAN_SWING = 8;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function pickLead(theories: Theory[]): Theory | null {
  if (theories.length === 0) return null;
  const active = theories.filter(
    (t) => t.status === "active" || t.status === "strengthening" || t.status === "weakening",
  );
  const pool = active.length > 0 ? active : theories;
  return pool.slice().sort((a, b) => b.confidence - a.confidence)[0] ?? null;
}

function beliefHypothesisAtPeriod(
  entries: JournalEntry[],
  periodKey: string,
): string | null {
  const sorted = [...eligible(entries)].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const cumulative = sorted.filter(
    (entry) => periodKeyFromIso(entry.createdAt) <= periodKey,
  );
  if (cumulative.length < 2) return null;

  const report = buildTheoryTrackerReport(cumulative, { persistSnapshots: false });
  const lead = pickLead(report.all);
  if (!lead) return null;
  return theoryToPersonalTheory(lead).hypothesis;
}

function isReversalNote(note: string): boolean {
  return /contradict|challeng|weaken|less confident|pulled in a different/i.test(note);
}

function findReversalIndex(points: BeliefTimelinePoint[]): number | null {
  let bestDrop = 0;
  let bestIndex: number | null = null;

  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1]!;
    const curr = points[i]!;
    const drop = prev.confidence - curr.confidence;
    const note = `${curr.note} ${curr.whatChanged}`;

    if (drop >= MIN_CONFIDENCE_SWING && drop > bestDrop) {
      bestDrop = drop;
      bestIndex = i;
      continue;
    }

    if (!prev.hasContradiction && curr.hasContradiction && bestIndex === null) {
      bestIndex = i;
      continue;
    }

    if (isReversalNote(note) && bestIndex === null) {
      bestIndex = i;
    }
  }

  if (bestIndex !== null) return bestIndex;

  const confidences = points.map((point) => point.confidence);
  const max = Math.max(...confidences);
  const min = Math.min(...confidences);
  if (max - min >= MIN_SPAN_SWING) {
    const minIndex = points.findIndex((point) => point.confidence === min);
    if (minIndex > 0) return minIndex;
  }

  return null;
}

function hasStoredReversal(theoryId: string): boolean {
  const history = readBeliefTimelineHistory(theoryId);
  if (history.length < 2) return false;

  for (let i = 1; i < history.length; i++) {
    const prev = history[i - 1]!;
    const curr = history[i]!;
    if (prev.confidence - curr.confidence >= MIN_CONFIDENCE_SWING) return true;
    if (isReversalNote(curr.note)) return true;
  }
  return false;
}

function buildArchiveExplanation(point: BeliefTimelinePoint | null): string {
  if (!point) {
    return "Contradicting moments shifted how strongly the archive holds this belief.";
  }

  const raw = (point.whatChanged || point.note).trim();
  if (raw && isReversalNote(raw)) {
    return toArchiveEmotionalCopy(raw);
  }
  if (point.hasContradiction) {
    return ARCHIVE_EMOTIONAL.contradictingEvidence;
  }
  return ARCHIVE_EMOTIONAL.theoryWeakened;
}

function formatPriorRead(point: BeliefTimelinePoint): string {
  return `${point.confidence}% · ${point.statusLabel} — ${toArchiveEmotionalCopy(point.whatChanged || point.note)}`;
}

export function buildContradictionHistoryView(
  entriesInput?: JournalEntry[],
  options?: { theoryId?: string },
): ContradictionHistoryView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const theoryId = options?.theoryId ?? belief.theoryId;
  const timeline = buildBeliefChangeTimeline(entries, { theoryId });
  if (!timeline || timeline.points.length < 2) return null;

  const reversalIndex = findReversalIndex(timeline.points);
  const storedReversal = hasStoredReversal(theoryId);
  if (reversalIndex === null && !storedReversal) return null;

  const index = reversalIndex ?? timeline.points.length - 1;
  const priorPoint = timeline.points[Math.max(0, index - 1)]!;
  const priorKey = priorPoint.periodKey;
  const priorHypothesis = beliefHypothesisAtPeriod(entries, priorKey);
  const previousBelief =
    priorHypothesis && priorHypothesis.trim() !== belief.belief.trim()
      ? priorHypothesis
      : formatPriorRead(priorPoint);

  const archiveExplanation = buildArchiveExplanation(timeline.points[index] ?? null);
  assertNoCertaintyLanguage(archiveExplanation);
  assertNoCertaintyLanguage(previousBelief);

  return {
    theoryId,
    headline: CONTRADICTION_HISTORY_HEADLINE,
    previousBelief,
    currentBelief: belief.belief,
    evidence: belief.evidence,
    archiveExplanation,
  };
}
