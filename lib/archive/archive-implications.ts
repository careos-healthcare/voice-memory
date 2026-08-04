import { buildArchiveAccuracyView } from "@/lib/archive/archive-accuracy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveImplication,
  ArchiveImplicationTypeId,
  ArchiveImplicationsView,
} from "@/types/archive-implications";
import type { JournalEntry } from "@/types/journal";

const MAX_CARD_LINES = 3;

const TYPE_PRIORITY: Record<ArchiveImplicationTypeId, number> = {
  CONFLICTING_EVIDENCE: 100,
  PERSISTENT_PATTERN: 95,
  CROSS_AREA_PATTERN: 88,
  WEAKENING: 82,
  STRENGTHENING: 80,
  LONG_RUNNING: 70,
  LIFE_AREA_CONCENTRATION: 62,
  NEW_PATTERN: 55,
};

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function formatAreaList(areas: string[]): string {
  const labels = areas.slice(0, 3).map((a) => a.toLowerCase());
  if (labels.length === 0) return "";
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]}`;
  return `${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}`;
}

function monthsPhrase(days: number): string | null {
  if (days < 60) return null;
  const months = Math.max(1, Math.round(days / 30));
  return `${months} month${months === 1 ? "" : "s"}`;
}

function dominantLifeArea(areas: string[]): string | null {
  if (areas.length === 0) return null;
  return areas[0]!.toLowerCase();
}

type ImplicationContext = {
  belief: NonNullable<ReturnType<typeof buildArchiveBeliefView>>;
  survival: ReturnType<typeof buildBeliefSurvivalView>;
  reputation: ReturnType<typeof buildArchiveReputationView>;
  accuracy: ReturnType<typeof buildArchiveAccuracyView>;
  contradiction: ReturnType<typeof buildContradictionHistoryView>;
  timelineChanges: number;
  reflectionCount: number;
  archiveSpanDays: number;
};

function buildContext(entries: JournalEntry[]): ImplicationContext | null {
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const stats = buildEvidenceArchiveStats(entries);
  const timelineChanges = readBeliefTimelineHistory(belief.theoryId).length;

  return {
    belief,
    survival: buildBeliefSurvivalView(entries, { theoryId: belief.theoryId }),
    reputation: buildArchiveReputationView(entries),
    accuracy: buildArchiveAccuracyView(entries),
    contradiction: buildContradictionHistoryView(entries, { theoryId: belief.theoryId }),
    timelineChanges,
    reflectionCount: stats.reflectionCount,
    archiveSpanDays: stats.daysCovered ?? belief.evidence.supportingQuotes.length,
  };
}

function pushImplication(
  list: ArchiveImplication[],
  type: ArchiveImplicationTypeId,
  text: string,
): void {
  const trimmed = text.trim();
  if (!trimmed) return;
  if (list.some((row) => row.type === type || row.text === trimmed)) return;
  list.push({
    id: newId("impl"),
    type,
    text: trimmed,
    priority: TYPE_PRIORITY[type],
  });
}

function collectCandidates(ctx: ImplicationContext, entries: JournalEntry[]): ArchiveImplication[] {
  const out: ArchiveImplication[] = [];
  const { belief, survival } = ctx;
  const daysAlive = survival?.daysAlive ?? 1;
  const areas = belief.evidence.lifeAreas;
  const contradicting = belief.evidence.contradictingQuotes.length;
  const survived = survival?.contradictionsSurvived ?? 0;

  if (daysAlive <= 14 && belief.status !== "resolved") {
    pushImplication(out, "NEW_PATTERN", "This belief appeared recently.");
  }

  if (daysAlive >= 21) {
    pushImplication(
      out,
      "LONG_RUNNING",
      `This belief has been present for ${daysAlive} days.`,
    );
  }

  if (belief.status === "strengthening") {
    const months = monthsPhrase(daysAlive);
    pushImplication(
      out,
      "STRENGTHENING",
      months
        ? `This belief has strengthened steadily for ${months}.`
        : "This belief has become stronger over time.",
    );
  } else if (belief.status === "weakening") {
    pushImplication(
      out,
      "WEAKENING",
      "Recent evidence has challenged this belief.",
    );
  } else {
    const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
    const lead = report.all.find((t) => t.id === belief.theoryId);
    if (lead?.previousConfidence !== undefined && lead.confidenceDelta >= 3) {
      pushImplication(
        out,
        "STRENGTHENING",
        `Confidence moved from ${clampConfidence(lead.previousConfidence)}% to ${clampConfidence(lead.confidence)}%.`,
      );
    } else if (lead?.previousConfidence !== undefined && lead.confidenceDelta <= -3) {
      pushImplication(out, "WEAKENING", "Recent evidence has challenged this belief.");
    }
  }

  if (areas.length >= 2) {
    pushImplication(
      out,
      "CROSS_AREA_PATTERN",
      areas.length >= 3
        ? "This pattern appears across multiple parts of your life."
        : `Evidence appears across ${formatAreaList(areas.slice(0, 2))}.`,
    );
  } else if (areas.length === 1) {
    const area = dominantLifeArea(areas);
    if (area) {
      pushImplication(
        out,
        "LIFE_AREA_CONCENTRATION",
        `Most evidence comes from ${area}.`,
      );
    }
  }

  if (
    contradicting > 0 ||
    ctx.contradiction != null ||
    ctx.accuracy?.beliefs.find((b) => b.theoryId === belief.theoryId)?.status ===
      "challenged"
  ) {
    pushImplication(
      out,
      "CONFLICTING_EVIDENCE",
      "The archive still sees conflicting evidence.",
    );
  }

  if (survived >= 2) {
    pushImplication(
      out,
      "PERSISTENT_PATTERN",
      "This belief survived multiple challenges.",
    );
  } else if (survived === 1 && daysAlive >= 30) {
    pushImplication(
      out,
      "PERSISTENT_PATTERN",
      "This belief survived a challenge and remained on record.",
    );
  }

  if (ctx.reputation && ctx.reputation.contradictionsSurvived >= 2 && !out.some((r) => r.type === "PERSISTENT_PATTERN")) {
    pushImplication(
      out,
      "PERSISTENT_PATTERN",
      `This belief survived ${ctx.reputation.contradictionsSurvived} contradictions without dropping.`,
    );
  }

  if (out.length === 0 && ctx.reflectionCount >= 3) {
    pushImplication(
      out,
      "LONG_RUNNING",
      `The archive is tracking this belief across ${ctx.reflectionCount} saved moment${ctx.reflectionCount === 1 ? "" : "s"}.`,
    );
  }

  return out;
}

/**
 * Derive archive implications from belief, timeline, evidence, and survival — no LLM.
 */
export function buildArchiveImplications(
  entriesInput?: JournalEntry[],
): ArchiveImplicationsView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const ctx = buildContext(entries);
  if (!ctx) return null;

  const sorted = collectCandidates(ctx, entries)
    .slice()
    .sort((a, b) => b.priority - a.priority);

  const headlineLines = sorted.slice(0, MAX_CARD_LINES).map((row) => row.text);

  return {
    theoryId: ctx.belief.theoryId,
    implications: sorted,
    headlineLines,
  };
}

export function implicationsAnswerLines(
  view: ArchiveImplicationsView | null,
): string[] {
  if (!view) {
    return ["The archive needs more saved moments before it can describe why this belief matters."];
  }
  if (view.headlineLines.length > 0) return view.headlineLines;
  return ["Significance lines will appear as the archive gathers more evidence."];
}
