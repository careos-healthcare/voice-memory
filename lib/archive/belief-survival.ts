import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildBeliefChangeTimeline } from "@/lib/archive/belief-timeline";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  BeliefSurvivalConfidenceMovement,
  BeliefSurvivalView,
} from "@/types/belief-survival";
import type { BeliefTimelinePoint } from "@/types/belief-timeline";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const BELIEF_SURVIVAL_TITLE = "Belief survival";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function pickLeadTheory(theories: Theory[]): Theory | null {
  if (theories.length === 0) return null;
  const active = theories.filter(
    (t) => t.status === "active" || t.status === "strengthening" || t.status === "weakening",
  );
  const pool = active.length > 0 ? active : theories;
  return pool.slice().sort((a, b) => b.confidence - a.confidence)[0] ?? null;
}

function formatFirstAppeared(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(iso));
}

function daysAliveSince(createdAt: string): number {
  return Math.max(
    1,
    daysBetweenKeys(toDayKey(createdAt), todayKey()) + 1,
  );
}

function uniqueSupportingReflectionCount(theory: Theory): number {
  return new Set(theory.supportingEvidence.map((q) => q.entryId)).size;
}

export function beliefSurvivedChallengesLine(count: number): string {
  return `This belief has survived ${count} challenge${count === 1 ? "" : "s"}.`;
}

export function beliefEvolvingDaysLine(days: number): string {
  return `This belief has been evolving for ${days} day${days === 1 ? "" : "s"}.`;
}

function movementFromTimelinePoints(
  points: Array<{
    id: string;
    periodLabel: string;
    confidence: number;
    note: string;
  }>,
): BeliefSurvivalConfidenceMovement[] {
  const movements: BeliefSurvivalConfidenceMovement[] = [];
  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1]!;
    const curr = points[i]!;
    const delta = clampConfidence(curr.confidence) - clampConfidence(prev.confidence);
    const deltaPart =
      delta === 0
        ? `${curr.confidence}%`
        : `${prev.confidence}% → ${curr.confidence}%`;
    const detail = [deltaPart, curr.note.trim()].filter(Boolean).join(" · ");
    movements.push({
      id: curr.id,
      label: curr.periodLabel,
      detail,
    });
  }
  return movements;
}

function buildConfidenceMovementHistory(
  theory: Theory,
  theoryId: string,
  entries: JournalEntry[],
): BeliefSurvivalConfidenceMovement[] {
  const history = readBeliefTimelineHistory(theoryId);
  let movements: BeliefSurvivalConfidenceMovement[] = [];

  if (history.length >= 2) {
    movements = movementFromTimelinePoints(
      history.map((row) => ({
        id: row.id,
        periodLabel: row.periodLabel,
        confidence: row.confidence,
        note: row.note,
      })),
    );
  } else {
    const timeline = buildBeliefChangeTimeline(entries, { theoryId });
    if (timeline && timeline.points.length >= 2) {
      movements = movementFromTimelinePoints(
        timeline.points.map((p: BeliefTimelinePoint) => ({
          id: p.id,
          periodLabel: p.periodLabel,
          confidence: p.confidence,
          note: p.note || p.whatChanged,
        })),
      );
    }
  }

  if (
    theory.previousConfidence !== undefined &&
    Math.abs(theory.confidenceDelta) >= 1
  ) {
    movements.push({
      id: "belief-survival-visit-delta",
      label: "Since last visit",
      detail: `${clampConfidence(theory.previousConfidence)}% → ${clampConfidence(theory.confidence)}%`,
    });
  }

  return movements.slice(-6);
}

function buildSummaryLines(
  daysAlive: number,
  contradictionsSurvived: number,
): string[] {
  const lines: string[] = [];
  if (daysAlive >= 2) {
    lines.push(beliefEvolvingDaysLine(daysAlive));
  }
  if (contradictionsSurvived >= 1) {
    lines.push(beliefSurvivedChallengesLine(contradictionsSurvived));
  }
  return lines;
}

export function buildBeliefSurvivalView(
  entriesInput?: JournalEntry[],
  options?: { theoryId?: string },
): BeliefSurvivalView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const theoryId = options?.theoryId ?? belief.theoryId;
  const lead =
    report.all.find((t) => t.id === theoryId) ?? pickLeadTheory(report.all);
  if (!lead) return null;

  const daysAlive = daysAliveSince(lead.createdAt);
  const reflectionsSupporting = Math.max(
    uniqueSupportingReflectionCount(lead),
    lead.supportingEvidenceCount,
  );
  const contradictionsSurvived = lead.contradictingEvidence.length;

  return {
    theoryId: lead.id,
    daysAlive,
    reflectionsSupporting,
    contradictionsSurvived,
    firstAppearedDate: formatFirstAppeared(lead.createdAt),
    confidenceMovementHistory: buildConfidenceMovementHistory(lead, lead.id, entries),
    summaryLines: buildSummaryLines(daysAlive, contradictionsSurvived),
  };
}
