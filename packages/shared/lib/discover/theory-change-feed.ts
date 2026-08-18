import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";
import { readDiscoverBaseline, readDiscoverLastVisitAt } from "@/lib/discover/discover-visit";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import type {
  Theory,
  TheoryChangeCategory,
  TheoryChangeFeedReport,
  TheoryChangeItem,
  TheoryStatus,
} from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const DELTA_THRESHOLD = 3;

function shortReasonFor(
  category: TheoryChangeCategory,
  theory: Theory,
  baselineConfidence?: number,
): string {
  if (theory.whatChanged[0]) return theory.whatChanged[0];
  switch (category) {
    case "strengthened":
      return baselineConfidence !== undefined
        ? ARCHIVE_EMOTIONAL.confidenceIncreased
        : ARCHIVE_EMOTIONAL.confidenceIncreased;
    case "weakened":
      return baselineConfidence !== undefined
        ? ARCHIVE_EMOTIONAL.theoryWeakened
        : ARCHIVE_EMOTIONAL.theoryWeakened;
    case "new":
      return "This theory was not in your last visit snapshot.";
    case "resolved":
      return "This theory no longer appears active in your current model.";
    default:
      return "Updated since your last visit.";
  }
}

function toChangeItem(
  theory: Theory,
  category: TheoryChangeCategory,
  confidenceDelta: number,
  baselineConfidence?: number,
): TheoryChangeItem {
  return {
    theoryId: theory.id,
    statement: theory.statement,
    confidence: theory.confidence,
    confidenceDelta,
    updatedAt: theory.updatedAt,
    shortReason: shortReasonFor(category, theory, baselineConfidence),
    category,
    source: theory.source,
    status: theory.status,
    supportingEvidenceCount: theory.supportingEvidenceCount,
    contradictingEvidenceCount: theory.contradictingEvidenceCount,
  };
}

function resolvedFromBaseline(
  baseline: NonNullable<ReturnType<typeof readDiscoverBaseline>>,
  currentById: Map<string, Theory>,
): TheoryChangeItem[] {
  const resolved: TheoryChangeItem[] = [];

  for (const prev of baseline.theories) {
    const current = currentById.get(prev.id);
    if (!current) {
      resolved.push({
        theoryId: prev.id,
        statement: prev.statement,
        confidence: prev.confidence,
        confidenceDelta: -prev.confidence,
        updatedAt: baseline.savedAt,
        shortReason: "This theory no longer appears active in your current model.",
        category: "resolved",
        source: prev.source,
        status: prev.status,
        supportingEvidenceCount: prev.supportingEntryIds.length,
        contradictingEvidenceCount: prev.contradictingEntryIds.length,
      });
      continue;
    }

    const wasOpen =
      prev.status === "active" ||
      prev.status === "weakening" ||
      prev.status === "resolved";
    const nowSettled =
      current.status === "strengthening" &&
      current.confidence >= 50 &&
      current.confidence > prev.confidence;
    if (wasOpen && nowSettled) {
      resolved.push(
        toChangeItem(
          current,
          "resolved",
          current.confidence - prev.confidence,
          prev.confidence,
        ),
      );
    }
  }

  return resolved;
}

function classifyChanges(
  baseline: NonNullable<ReturnType<typeof readDiscoverBaseline>>,
  current: Theory[],
): Omit<TheoryChangeFeedReport, "generatedAt" | "hasBaseline" | "lastVisitAt" | "totalChanges"> {
  const baselineById = new Map(baseline.theories.map((t) => [t.id, t]));
  const currentById = new Map(current.map((t) => [t.id, t]));

  const strengthened: TheoryChangeItem[] = [];
  const weakened: TheoryChangeItem[] = [];
  const newItems: TheoryChangeItem[] = [];
  const resolved: TheoryChangeItem[] = [];

  for (const theory of current) {
    const prev = baselineById.get(theory.id);
    if (!prev) {
      newItems.push(toChangeItem(theory, "new", theory.confidence, undefined));
      continue;
    }

    const delta = theory.confidence - prev.confidence;
    if (delta >= DELTA_THRESHOLD) {
      strengthened.push(toChangeItem(theory, "strengthened", delta, prev.confidence));
    } else if (delta <= -DELTA_THRESHOLD) {
      weakened.push(toChangeItem(theory, "weakened", delta, prev.confidence));
    } else if (theory.status === "active" && prev.status !== "active" && theory.confidence < 55) {
      newItems.push(toChangeItem(theory, "new", delta, prev.confidence));
    }
  }

  resolved.push(...resolvedFromBaseline(baseline, currentById));

  const sortByDelta = (a: TheoryChangeItem, b: TheoryChangeItem) =>
    Math.abs(b.confidenceDelta) - Math.abs(a.confidenceDelta);

  return {
    strengthened: strengthened.sort(sortByDelta),
    weakened: weakened.sort(sortByDelta),
    new: newItems.sort(sortByDelta),
    resolved: resolved.sort(sortByDelta),
  };
}

/** Compare current theories to last discover visit baseline. */
export function buildTheoryChangeFeed(entries: JournalEntry[]): TheoryChangeFeedReport {
  const baseline = readDiscoverBaseline();
  const lastVisitAt = readDiscoverLastVisitAt();
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
  const current = report.all;

  if (!baseline) {
    return {
      generatedAt: new Date().toISOString(),
      hasBaseline: false,
      lastVisitAt,
      strengthened: [],
      weakened: [],
      new: [],
      resolved: [],
      totalChanges: 0,
    };
  }

  const sections = classifyChanges(baseline, current);
  const totalChanges =
    sections.strengthened.length +
    sections.weakened.length +
    sections.new.length +
    sections.resolved.length;

  return {
    generatedAt: new Date().toISOString(),
    hasBaseline: true,
    lastVisitAt: baseline.savedAt ?? lastVisitAt,
    ...sections,
    totalChanges,
  };
}

export function isTheoryStatus(value: string): value is TheoryStatus {
  return ["active", "strengthening", "weakening", "resolved", "retired"].includes(value);
}
