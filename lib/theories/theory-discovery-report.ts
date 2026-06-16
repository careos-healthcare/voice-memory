import { buildTheoryVolatilityReport } from "@/lib/discover/theory-volatility";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import { readAllTheoryEvents } from "@/lib/theories/theory-events";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import type {
  TheoryDiscoveryReport,
  TheoryFeedbackReaction,
  TheorySource,
  TheorySourceBreakdown,
} from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

const REACTIONS: TheoryFeedbackReaction[] = [
  "feels_true",
  "partly_true",
  "not_true",
  "too_obvious",
  "surprising",
];

function emptyFeedbackCounts(): Record<TheoryFeedbackReaction, number> {
  return {
    feels_true: 0,
    partly_true: 0,
    not_true: 0,
    too_obvious: 0,
    surprising: 0,
  };
}

export function buildTheoryDiscoveryReport(
  entries: JournalEntry[],
): TheoryDiscoveryReport {
  const report = buildTheoryTrackerReport(entries);
  const feedback = readAllTheoryFeedback();
  const events = readAllTheoryEvents();

  const viewedIds = new Set(
    events.filter((e) => e.name === "theory_viewed" && e.theoryId).map((e) => e.theoryId!),
  );
  const expandedIds = new Set(
    events.filter((e) => e.name === "theory_expanded" && e.theoryId).map((e) => e.theoryId!),
  );
  const revisited = events.filter((e) => e.name === "theory_revisited").length;
  const views = events.filter((e) => e.name === "theory_viewed").length;

  const feedbackCounts = emptyFeedbackCounts();
  for (const row of feedback) {
    feedbackCounts[row.reaction] += 1;
  }

  const changed = report.all.filter(
    (t) => t.previousConfidence !== undefined && Math.abs(t.confidenceDelta) >= 4,
  );

  const strongestIncreases = [...report.all]
    .filter((t) => t.confidenceDelta > 0)
    .sort((a, b) => b.confidenceDelta - a.confidenceDelta)
    .slice(0, 5)
    .map((t) => ({
      theoryId: t.id,
      statement: t.statement.slice(0, 120),
      delta: t.confidenceDelta,
    }));

  const strongestDecreases = [...report.all]
    .filter((t) => t.confidenceDelta < 0)
    .sort((a, b) => a.confidenceDelta - b.confidenceDelta)
    .slice(0, 5)
    .map((t) => ({
      theoryId: t.id,
      statement: t.statement.slice(0, 120),
      delta: t.confidenceDelta,
    }));

  const surprisingByTheory = new Map<string, { statement: string; count: number }>();
  const notTrueByTheory = new Map<string, { statement: string; count: number }>();

  for (const row of feedback) {
    if (row.reaction === "surprising") {
      const cur = surprisingByTheory.get(row.theoryId) ?? {
        statement: row.statement.slice(0, 120),
        count: 0,
      };
      cur.count += 1;
      surprisingByTheory.set(row.theoryId, cur);
    }
    if (row.reaction === "not_true") {
      const cur = notTrueByTheory.get(row.theoryId) ?? {
        statement: row.statement.slice(0, 120),
        count: 0,
      };
      cur.count += 1;
      notTrueByTheory.set(row.theoryId, cur);
    }
  }

  const sources: TheorySource[] = ["blind_spot", "pattern", "prediction", "emerging"];
  const sourceBreakdown: TheorySourceBreakdown[] = sources.map((source) => ({
    source,
    count: report.all.filter((t) => t.source === source).length,
  }));

  return {
    generatedAt: new Date().toISOString(),
    totalTheories: report.all.length,
    resolvedCount: report.resolved.length,
    retiredCount: report.retired.length,
    viewedTheories: viewedIds.size,
    expandedTheories: expandedIds.size,
    feedbackCounts,
    revisitRate: views > 0 ? Math.round((revisited / views) * 100) : 0,
    changedTheoryRate:
      report.all.length > 0
        ? Math.round((changed.length / report.all.length) * 100)
        : 0,
    strongestIncreases,
    strongestDecreases,
    mostSurprising: [...surprisingByTheory.entries()]
      .map(([theoryId, v]) => ({ theoryId, statement: v.statement, count: v.count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5),
    mostNotTrue: [...notTrueByTheory.entries()]
      .map(([theoryId, v]) => ({ theoryId, statement: v.statement, count: v.count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5),
    sourceBreakdown,
    volatility: buildTheoryVolatilityReport(),
  };
}
