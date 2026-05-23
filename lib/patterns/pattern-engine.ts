import { addDaysToKey, toDayKey } from "@/lib/dates";
import {
  buildEntityMemoryFromEntries,
  formatEntityTypeLabel,
  type TrackedEntity,
} from "@/lib/entity-memory";
import { countFeedbackByRating, readAllFeedback } from "@/lib/feedback-storage";
import { detectAllAvoidanceSignals } from "@/lib/patterns/avoidance";
import { detectAllContradictions } from "@/lib/patterns/contradictions";
import { buildEmotionalEvolutionReport } from "@/lib/patterns/emotional-evolution";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { analyzeWeeklyIntelligence } from "@/lib/weekly-intelligence";
import {
  scoreInsightSpecificity,
  type SpecificityScoreResult,
} from "@/lib/patterns/specificity-score";
import type { JournalEntry } from "@/types/journal";

export type { SpecificityScoreResult as PatternInsightSpecificity };

export type PatternInsightType =
  | "recurring_pattern"
  | "contradiction"
  | "repeated_phrase"
  | "avoidance_signal"
  | "emotional_cycle"
  | "entity_trigger"
  | "improvement_signal";

export type PatternEngineScope = "archive" | "weekly" | "memory" | "entry";

export interface PatternInsightEvidence {
  entryId: string;
  dateLabel?: string;
  phrase: string;
  mood?: string;
}

export interface PatternInsightScores {
  specificity: number;
  recurrenceCount: number;
  crossEntryGrounding: number;
  exactPhraseEvidence: number;
  userUsefulness: number;
  total: number;
}

export interface PatternInsight {
  id: string;
  type: PatternInsightType;
  title: string;
  detail: string;
  evidence: PatternInsightEvidence[];
  entryIds: string[];
  scores: PatternInsightScores;
  specificity: SpecificityScoreResult;
  sourceKey: string;
}

export interface PatternEngineReport {
  insights: PatternInsight[];
  hasData: boolean;
  generatedAt: string;
  scope: PatternEngineScope;
}

export interface PatternEngineOptions {
  scope?: PatternEngineScope;
  entryId?: string;
  limit?: number;
}

const TYPE_USEFULNESS_BASE: Record<PatternInsightType, number> = {
  recurring_pattern: 55,
  contradiction: 60,
  repeated_phrase: 50,
  avoidance_signal: 45,
  emotional_cycle: 55,
  entity_trigger: 58,
  improvement_signal: 52,
};

const MEMORY_TYPES = new Set<PatternInsightType>([
  "recurring_pattern",
  "repeated_phrase",
  "entity_trigger",
  "avoidance_signal",
]);

function scoreInsight(
  input: {
    type: PatternInsightType;
    title: string;
    detail: string;
    evidence: PatternInsightEvidence[];
    entryIds: string[];
    recurrenceCount: number;
  },
  specificity: SpecificityScoreResult,
): PatternInsightScores {
  const { type, evidence, entryIds, recurrenceCount } = input;

  const recurrence = Math.min(100, recurrenceCount * 18);
  const crossEntryGrounding = Math.min(100, entryIds.length * 28);
  const exactPhraseEvidence = Math.min(
    100,
    evidence.length * 18 + (specificity.evidenceSources.includes("exact_phrase") ? 25 : 0),
  );

  const feedback = countFeedbackByRating();
  const feedbackBoost =
    feedback.up > feedback.down ? 12 : feedback.down > feedback.up ? -8 : 0;
  const userUsefulness = Math.min(
    100,
    Math.max(20, TYPE_USEFULNESS_BASE[type] + feedbackBoost),
  );

  const total = Math.min(
    100,
    Math.round(
      specificity.specificityScore * 0.35 +
        recurrence * 0.2 +
        crossEntryGrounding * 0.2 +
        exactPhraseEvidence * 0.15 +
        userUsefulness * 0.1,
    ),
  );

  return {
    specificity: specificity.specificityScore,
    recurrenceCount: recurrence,
    crossEntryGrounding,
    exactPhraseEvidence,
    userUsefulness,
    total,
  };
}

function insightFromParts(
  id: string,
  type: PatternInsightType,
  title: string,
  detail: string,
  evidence: PatternInsightEvidence[],
  entryIds: string[],
  recurrenceCount: number,
  sourceKey: string,
  entries: JournalEntry[],
): PatternInsight {
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const slicedEvidence = evidence.slice(0, 6);
  const uniqueEntryIds = [...new Set(entryIds)];

  const specificity = scoreInsightSpecificity({
    type,
    title,
    detail,
    evidence: slicedEvidence,
    entryIds: uniqueEntryIds,
    recurrenceCount,
    entriesById,
  });

  return {
    id,
    type,
    title,
    detail,
    evidence: slicedEvidence,
    entryIds: uniqueEntryIds,
    specificity,
    scores: scoreInsight(
      {
        type,
        title,
        detail,
        evidence: slicedEvidence,
        entryIds: uniqueEntryIds,
        recurrenceCount,
      },
      specificity,
    ),
    sourceKey,
  };
}

function collectContradictionInsights(entries: JournalEntry[]): PatternInsight[] {
  return detectAllContradictions(entries).map((c) =>
    insightFromParts(
      `contradiction:${c.id}`,
      "contradiction",
      c.title,
      c.explanation,
      c.evidence.map((e) => ({
        entryId: e.entryId,
        dateLabel: e.dateLabel,
        phrase: e.phrase,
        mood: e.mood,
      })),
      c.entryIds,
      c.evidence.length,
      c.id,
      entries,
    ),
  );
}

function collectPhraseInsights(entries: JournalEntry[]): PatternInsight[] {
  return buildPhraseMemory(entries).map((p) =>
    insightFromParts(
      `phrase:${p.category}:${p.phrase}`,
      "repeated_phrase",
      `"${p.phrase}" returns across your archive`,
      `${p.count} uses in ${p.entryIds.length} entries · ${p.category.replace("_", " ")}${p.dominantMood ? ` · often around ${p.dominantMood}` : ""}`,
      p.occurrences.map((o) => ({
        entryId: o.entryId,
        dateLabel: o.dateLabel,
        phrase: o.snippet,
        mood: o.mood,
      })),
      p.entryIds,
      p.count,
      p.phrase,
      entries,
    ),
  );
}

function collectAvoidanceInsights(entries: JournalEntry[]): PatternInsight[] {
  return detectAllAvoidanceSignals(entries).map((s) =>
    insightFromParts(
      `avoidance:${s.id}`,
      "avoidance_signal",
      s.title,
      s.explanation,
      s.evidence.map((e) => ({
        entryId: e.entryId,
        dateLabel: e.dateLabel,
        phrase: e.phrase,
        mood: e.mood,
      })),
      s.entryIds,
      s.evidence.length,
      s.id,
      entries,
    ),
  );
}

function collectEvolutionInsights(entries: JournalEntry[]): PatternInsight[] {
  const report = buildEmotionalEvolutionReport(entries);
  const results: PatternInsight[] = [];

  for (const item of report.insights) {
    const type: PatternInsightType =
      item.kind === "period_comparison" && item.line.includes("calmer")
        ? "improvement_signal"
        : item.kind === "intensity_drift" && item.line.includes("downward")
          ? "improvement_signal"
          : ["emotional_cycle", "day_of_week", "recurring_trigger"].includes(item.kind)
            ? item.kind === "emotional_cycle"
              ? "emotional_cycle"
              : item.kind === "recurring_trigger"
                ? "entity_trigger"
                : "emotional_cycle"
            : "emotional_cycle";

    results.push(
      insightFromParts(
        `evolution:${item.id}`,
        type,
        item.line,
        item.detail ?? item.line,
        item.entryIds.map((id) => {
          const entry = entries.find((e) => e.id === id);
          return {
            entryId: id,
            phrase: entry?.reflection.exactLanguagePattern ?? entry?.transcript.slice(0, 120) ?? "",
            mood: entry?.reflection.mood,
          };
        }).filter((e) => e.phrase),
        item.entryIds,
        item.entryIds.length,
        item.id,
        entries,
      ),
    );
  }

  for (const line of report.weekComparison.lines) {
    if (!line.includes("calmer") && !line.includes("less intense")) continue;
    results.push(
      insightFromParts(
        `improvement:${line.slice(0, 32)}`,
        "improvement_signal",
        line,
        "Week-over-week shift in how charged your reflections sound — pattern observation only.",
        [],
        entries.slice(-14).map((e) => e.id),
        2,
        "week-comparison",
        entries,
      ),
    );
  }

  return results;
}

function collectEntityInsights(entries: JournalEntry[]): PatternInsight[] {
  const snapshot = buildEntityMemoryFromEntries(entries);
  const results: PatternInsight[] = [];

  const allEntities: TrackedEntity[] = [
    ...snapshot.people,
    ...snapshot.concerns,
    ...snapshot.goals,
    ...snapshot.topics,
  ];

  for (const entity of allEntities.filter((e) => e.mentionCount >= 2).slice(0, 8)) {
    results.push(
      insightFromParts(
        `entity:${entity.id}`,
        "entity_trigger",
        `You mentioned ${entity.name} ${entity.mentionCount} times`,
        `Recurring ${formatEntityTypeLabel(entity.type).toLowerCase()} across your archive${entity.relatedMoods.length ? ` · moods like ${entity.relatedMoods.slice(0, 3).join(", ")}` : ""}`,
        entity.sampleEntryIds.map((id) => {
          const entry = entries.find((e) => e.id === id);
          return {
            entryId: id,
            phrase:
              entry?.reflection.exactLanguagePattern ??
              entry?.transcript.slice(0, 120) ??
              entity.name,
            mood: entry?.reflection.mood,
          };
        }),
        entity.entryIds,
        entity.mentionCount,
        entity.id,
        entries,
      ),
    );
  }

  const themeMap = new Map<string, { count: number; entryIds: string[] }>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase().trim();
      if (!key) continue;
      const row = themeMap.get(key) ?? { count: 0, entryIds: [] };
      row.count += 1;
      row.entryIds.push(entry.id);
      themeMap.set(key, row);
    }
  }

  for (const [theme, row] of themeMap.entries()) {
    if (row.count < 2) continue;
    results.push(
      insightFromParts(
        `theme:${theme}`,
        "recurring_pattern",
        `"${theme}" keeps returning in your words`,
        `Appeared in ${row.entryIds.length} reflections — a recurring thread in your archive.`,
        row.entryIds.slice(0, 4).map((id) => {
          const entry = entries.find((e) => e.id === id);
          return {
            entryId: id,
            phrase: entry?.reflection.patternObservations?.[0] ?? entry?.transcript.slice(0, 100) ?? theme,
            mood: entry?.reflection.mood,
          };
        }),
        row.entryIds,
        row.count,
        theme,
        entries,
      ),
    );
  }

  return results;
}

function recentEntryIds(entries: JournalEntry[], days = 7): string[] {
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return entries.filter((e) => toDayKey(e.createdAt) >= cutoff).map((e) => e.id);
}

function collectWeeklyInsights(entries: JournalEntry[]): PatternInsight[] {
  const weekly = analyzeWeeklyIntelligence();
  if (!weekly.hasData) return [];

  const weekEntryIds = recentEntryIds(entries, 7);
  const results: PatternInsight[] = [];

  for (const theme of weekly.thisWeek.recurringThemes.slice(0, 3)) {
    results.push(
      insightFromParts(
        `weekly-theme:${theme.label}`,
        "recurring_pattern",
        `"${theme.label}" surfaced ${theme.count} time${theme.count === 1 ? "" : "s"} this week`,
        `Dominant recurring theme in the last 7 days — from your words only.`,
        [],
        weekEntryIds,
        theme.count,
        `weekly:${theme.label}`,
        entries,
      ),
    );
  }

  if (weekly.emotionalShift.direction === "calmer") {
    results.push(
      insightFromParts(
        "weekly-improvement:calmer",
        "improvement_signal",
        weekly.emotionalShift.label,
        weekly.emotionalShift.detail,
        [],
        weekEntryIds,
        weekly.thisWeek.entryCount,
        "weekly:shift",
        entries,
      ),
    );
  } else if (weekly.emotionalShift.direction === "intenser") {
    results.push(
      insightFromParts(
        "weekly-cycle:intenser",
        "emotional_cycle",
        weekly.emotionalShift.label,
        weekly.emotionalShift.detail,
        [],
        weekEntryIds,
        weekly.thisWeek.entryCount,
        "weekly:shift",
        entries,
      ),
    );
  }

  return results;
}

function applyUsefulnessFromFeedback(insights: PatternInsight[]): PatternInsight[] {
  const records = readAllFeedback();
  const upTargets = new Set(
    records.filter((r) => r.rating === "up").map((r) => r.targetKey),
  );

  return insights.map((insight) => {
    const entryBoost = insight.entryIds.some((id) => upTargets.has(id)) ? 8 : 0;
    const globalBoost = upTargets.has("global") ? 5 : 0;
    const boost = entryBoost + globalBoost;
    if (boost === 0) return insight;

    return {
      ...insight,
      scores: {
        ...insight.scores,
        userUsefulness: Math.min(100, insight.scores.userUsefulness + boost),
        total: Math.min(100, insight.scores.total + Math.round(boost * 0.5)),
      },
    };
  });
}

function dedupeInsights(insights: PatternInsight[]): PatternInsight[] {
  const seen = new Set<string>();
  return insights.filter((i) => {
    const key = `${i.type}:${i.sourceKey}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function filterByScope(
  insights: PatternInsight[],
  scope: PatternEngineScope,
  entryId?: string,
): PatternInsight[] {
  switch (scope) {
    case "weekly":
      return insights;

    case "memory":
      return insights.filter((i) => MEMORY_TYPES.has(i.type));

    case "entry":
      if (!entryId) return [];
      return insights.filter((i) => i.entryIds.includes(entryId));

    case "archive":
    default:
      return insights;
  }
}

function filterWeeklyByDate(
  insights: PatternInsight[],
  entries: JournalEntry[],
): PatternInsight[] {
  const recentIds = new Set(recentEntryIds(entries, 7));

  return insights.filter(
    (i) =>
      i.sourceKey.startsWith("weekly") ||
      i.id.startsWith("weekly") ||
      i.entryIds.some((id) => recentIds.has(id)),
  );
}

/** Build ranked pattern-first insights from all detection modules. */
export function buildPatternEngineReport(
  entries: JournalEntry[],
  options: PatternEngineOptions = {},
): PatternEngineReport {
  const scope = options.scope ?? "archive";
  const limit = options.limit ?? 12;

  if (entries.length === 0) {
    return {
      insights: [],
      hasData: false,
      generatedAt: new Date().toISOString(),
      scope,
    };
  }

  let insights = dedupeInsights([
    ...collectContradictionInsights(entries),
    ...collectPhraseInsights(entries),
    ...collectAvoidanceInsights(entries),
    ...collectEvolutionInsights(entries),
    ...collectEntityInsights(entries),
    ...collectWeeklyInsights(entries),
  ]);

  insights = applyUsefulnessFromFeedback(insights);
  insights = filterByScope(insights, scope, options.entryId);

  if (scope === "weekly") {
    insights = filterWeeklyByDate(insights, entries);
  }

  insights = insights
    .sort(
      (a, b) =>
        b.specificity.specificityScore - a.specificity.specificityScore ||
        b.scores.total - a.scores.total ||
        b.entryIds.length - a.entryIds.length,
    )
    .slice(0, limit);

  return {
    insights,
    hasData: insights.length > 0,
    generatedAt: new Date().toISOString(),
    scope,
  };
}

/** Convenience helper for page-level scope filtering. */
export function getPatternInsights(
  entries: JournalEntry[],
  scope: PatternEngineScope,
  entryId?: string,
  limit = 10,
): PatternInsight[] {
  return buildPatternEngineReport(entries, { scope, entryId, limit }).insights;
}

export function typeLabel(type: PatternInsightType): string {
  const labels: Record<PatternInsightType, string> = {
    recurring_pattern: "Recurring pattern",
    contradiction: "Contradiction",
    repeated_phrase: "Repeated phrase",
    avoidance_signal: "Indirect language",
    emotional_cycle: "Emotional cycle",
    entity_trigger: "Entity trigger",
    improvement_signal: "Shift toward calmer",
  };
  return labels[type];
}
