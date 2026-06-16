import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import {
  MILESTONE_EXPLANATIONS,
  MILESTONE_TITLES,
} from "@/lib/archive/archive-milestone-copy";
import { readArchiveQuestionEngagedAt } from "@/lib/archive/archive-milestone-storage";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveMilestone,
  ArchiveMilestoneTypeId,
  ArchiveMilestonesView,
} from "@/types/archive-milestone";
import type { JournalEntry } from "@/types/journal";

const RECURRING_PHRASE_MIN = 3;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function formatPeriodLabel(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    day: "numeric",
  }).format(new Date(iso));
}

function entryAt(sorted: JournalEntry[], index: number): string {
  return sorted[Math.min(index, sorted.length - 1)]!.createdAt;
}

function firstIndexWhere(
  sorted: JournalEntry[],
  predicate: (subset: JournalEntry[]) => boolean,
): number | null {
  for (let i = 1; i <= sorted.length; i++) {
    if (predicate(sorted.slice(0, i))) return i - 1;
  }
  return null;
}

function pushMilestone(
  list: ArchiveMilestone[],
  type: ArchiveMilestoneTypeId,
  occurredAt: string,
): void {
  if (list.some((m) => m.type === type)) return;
  list.push({
    id: newId("ms"),
    type,
    title: MILESTONE_TITLES[type],
    explanation: MILESTONE_EXPLANATIONS[type],
    occurredAt,
    periodLabel: formatPeriodLabel(occurredAt),
  });
}

function detectMilestones(entries: JournalEntry[]): ArchiveMilestone[] {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  if (sorted.length === 0) return [];

  const out: ArchiveMilestone[] = [];
  const full = sorted;

  pushMilestone(out, "FIRST_REFLECTION", sorted[0]!.createdAt);

  const countMilestones: Array<{ type: ArchiveMilestoneTypeId; n: number }> = [
    { type: "TEN_REFLECTIONS", n: 10 },
    { type: "FIFTY_REFLECTIONS", n: 50 },
    { type: "ONE_HUNDRED_REFLECTIONS", n: 100 },
  ];
  for (const { type, n } of countMilestones) {
    if (sorted.length >= n) {
      pushMilestone(out, type, entryAt(sorted, n - 1));
    }
  }

  const firstBeliefIdx = firstIndexWhere(sorted, (subset) =>
    Boolean(buildArchiveBeliefView(subset)),
  );
  if (firstBeliefIdx != null) {
    pushMilestone(out, "FIRST_BELIEF", sorted[firstBeliefIdx]!.createdAt);
  }

  const firstChangeIdx = firstIndexWhere(sorted, (subset) => {
    const belief = buildArchiveBeliefView(subset);
    if (!belief) return false;
    const timeline = readBeliefTimelineHistory(belief.theoryId).length;
    return belief.changeLines.length > 0 || timeline > 0;
  });
  if (firstChangeIdx != null) {
    pushMilestone(out, "FIRST_BELIEF_CHANGE", sorted[firstChangeIdx]!.createdAt);
  }

  const firstContradictionIdx = firstIndexWhere(sorted, (subset) => {
    const belief = buildArchiveBeliefView(subset);
    return Boolean(belief && belief.evidence.contradictingQuotes.length > 0);
  });
  if (firstContradictionIdx != null) {
    pushMilestone(out, "FIRST_CONTRADICTION", sorted[firstContradictionIdx]!.createdAt);
  }

  const firstCrossIdx = firstIndexWhere(sorted, (subset) => {
    const belief = buildArchiveBeliefView(subset);
    return Boolean(belief && belief.evidence.lifeAreas.length >= 2);
  });
  if (firstCrossIdx != null) {
    pushMilestone(out, "FIRST_CROSS_LIFE_PATTERN", sorted[firstCrossIdx]!.createdAt);
  }

  const firstStrongIdx = firstIndexWhere(sorted, (subset) => {
    const belief = buildArchiveBeliefView(subset);
    if (!belief) return false;
    if (belief.confidence >= 72 || belief.status === "strengthening") return true;
    const rep = buildArchiveReputationView(subset);
    return rep != null && (rep.level === "high" || rep.level === "very_high");
  });
  if (firstStrongIdx != null) {
    pushMilestone(out, "FIRST_STRONG_BELIEF", sorted[firstStrongIdx]!.createdAt);
  }

  const mindChangedIdx = firstIndexWhere(sorted, (subset) =>
    Boolean(buildContradictionHistoryView(subset)),
  );
  if (mindChangedIdx != null) {
    pushMilestone(out, "ARCHIVE_CHANGED_ITS_MIND", sorted[mindChangedIdx]!.createdAt);
  }

  const survivedIdx = firstIndexWhere(sorted, (subset) => {
    const belief = buildArchiveBeliefView(subset);
    if (!belief) return false;
    const survival = buildBeliefSurvivalView(subset, { theoryId: belief.theoryId });
    return Boolean(survival && survival.contradictionsSurvived >= 1);
  });
  if (survivedIdx != null) {
    pushMilestone(out, "FIRST_SURVIVED_CHALLENGE", sorted[survivedIdx]!.createdAt);
  }

  const repStrongIdx = firstIndexWhere(sorted, (subset) => {
    const rep = buildArchiveReputationView(subset);
    return rep != null && (rep.level === "high" || rep.level === "very_high");
  });
  if (repStrongIdx != null) {
    pushMilestone(out, "FIRST_REPUTATION_STRONG", sorted[repStrongIdx]!.createdAt);
  }

  const phraseIdx = firstIndexWhere(sorted, (subset) => {
    const phrases = buildPhraseMemory(subset);
    return phrases.some((p) => p.count >= RECURRING_PHRASE_MIN);
  });
  if (phraseIdx != null) {
    pushMilestone(out, "FIRST_RECURRING_PATTERN", sorted[phraseIdx]!.createdAt);
  }

  const stats = buildEvidenceArchiveStats(full);
  const spanDays = stats.daysCovered ?? 0;
  if (spanDays >= 30) {
    const target = sorted[0]!;
    let walk = target.createdAt;
    for (const entry of sorted) {
      const days = daysBetweenKeys(toDayKey(target.createdAt), toDayKey(entry.createdAt)) + 1;
      if (days >= 30) {
        walk = entry.createdAt;
        break;
      }
    }
    pushMilestone(out, "THIRTY_DAYS_OF_HISTORY", walk);
  }
  if (spanDays >= 90) {
    let walk = sorted[0]!.createdAt;
    for (const entry of sorted) {
      const days = daysBetweenKeys(toDayKey(sorted[0]!.createdAt), toDayKey(entry.createdAt)) + 1;
      if (days >= 90) {
        walk = entry.createdAt;
        break;
      }
    }
    pushMilestone(out, "NINETY_DAYS_OF_HISTORY", walk);
  }

  const questionAt = readArchiveQuestionEngagedAt();
  if (questionAt) {
    pushMilestone(out, "FIRST_ARCHIVE_QUESTION_ANSWERED", questionAt);
  }

  return out.sort(
    (a, b) => new Date(a.occurredAt).getTime() - new Date(b.occurredAt).getTime(),
  );
}

/**
 * Build archive milestones from existing systems — no new intelligence, no gamification.
 */
export function buildArchiveMilestones(
  entriesInput?: JournalEntry[],
): ArchiveMilestonesView {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const milestones = detectMilestones(entries);
  const latest =
    milestones.length > 0 ? milestones[milestones.length - 1]! : null;
  return { milestones, latest };
}

export function recentArchiveMilestones(
  view: ArchiveMilestonesView,
  limit = 5,
): ArchiveMilestone[] {
  return view.milestones.slice(-limit).reverse();
}
