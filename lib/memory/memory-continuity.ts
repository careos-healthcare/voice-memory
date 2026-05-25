import { daysBetweenKeys, startOfWeekKey, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { getEntryPreviewLine } from "@/lib/reflection";
import { getEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  LastMentionedReference,
  MemoryContinuityMatchReason,
  MemoryContinuityReport,
  RecurringEmotionalPattern,
  RelatedReflection,
  RepeatedConcern,
} from "@/types/memory-continuity";

const STOPWORDS = new Set([
  "about",
  "after",
  "again",
  "also",
  "been",
  "being",
  "could",
  "does",
  "dont",
  "from",
  "have",
  "just",
  "like",
  "more",
  "really",
  "said",
  "some",
  "that",
  "them",
  "then",
  "there",
  "these",
  "they",
  "this",
  "today",
  "very",
  "want",
  "were",
  "what",
  "when",
  "with",
  "would",
  "your",
]);

const WEIGHTS = {
  themes: 25,
  mood: 15,
  entities: 20,
  keywords: 15,
  concern: 15,
  recommendation: 10,
} as const;

const MIN_SCORE = 20;
const MAX_RELATED = 5;
const MAX_PREVIOUS_WEEKS = 4;

interface ScoredPair {
  entry: JournalEntry;
  score: number;
  reasons: MemoryContinuityMatchReason[];
  daysApart: number;
}

function normalizeText(text: string): string {
  return text.trim().toLowerCase().replace(/\s+/g, " ");
}

function extractKeywords(...parts: string[]): Set<string> {
  const tokens = new Set<string>();
  for (const part of parts) {
    if (!part.trim()) continue;
    for (const word of part.toLowerCase().replace(/[^\w\s']/g, " ").split(/\s+/)) {
      if (word.length >= 4 && !STOPWORDS.has(word)) {
        tokens.add(word);
      }
    }
  }
  return tokens;
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const item of a) {
    if (b.has(item)) intersection += 1;
  }
  const union = a.size + b.size - intersection;
  return union > 0 ? intersection / union : 0;
}

function themeSet(entry: JournalEntry): Set<string> {
  return new Set(
    entry.reflection.recurringThemes.map((t) => normalizeText(t)).filter(Boolean),
  );
}

function concernText(entry: JournalEntry): string {
  return [
    entry.reflection.hiddenConcern,
    entry.reflection.avoidedOrVagueArea,
    entry.reflection.repeatedSignal,
    entry.reflection.tensionOrContradiction,
  ]
    .filter(Boolean)
    .join(" ");
}

function recommendationText(entry: JournalEntry): string {
  return [entry.reflection.recommendation, entry.reflection.nextSmallAction]
    .filter(Boolean)
    .join(" ");
}

function entityNamesForEntry(
  entryId: string,
  entries: JournalEntry[],
): Set<string> {
  const snapshot = buildEntityMemoryFromEntries(entries);
  const names = new Set<string>();

  for (const group of [
    snapshot.people,
    snapshot.concerns,
    snapshot.goals,
    snapshot.topics,
  ]) {
    for (const entity of group) {
      if (entity.entryIds.includes(entryId)) {
        names.add(normalizeText(entity.name));
      }
    }
  }

  return names;
}

function scorePair(target: JournalEntry, candidate: JournalEntry): ScoredPair {
  const reasons: MemoryContinuityMatchReason[] = [];
  let score = 0;

  const targetThemes = themeSet(target);
  const candidateThemes = themeSet(candidate);
  const themeOverlap = jaccard(targetThemes, candidateThemes);
  if (themeOverlap > 0) {
    score += themeOverlap * WEIGHTS.themes;
    reasons.push("themes");
  }

  const targetMood = normalizeText(target.reflection.mood);
  const candidateMood = normalizeText(candidate.reflection.mood);
  if (targetMood && candidateMood) {
    if (targetMood === candidateMood) {
      score += WEIGHTS.mood;
      reasons.push("mood");
    } else if (
      targetMood.slice(0, 4) === candidateMood.slice(0, 4) ||
      Math.abs(target.reflection.emotionalIntensity - candidate.reflection.emotionalIntensity) <= 1
    ) {
      score += WEIGHTS.mood * 0.45;
      reasons.push("mood");
    }
  }

  const allEntries = getEntries();
  const targetEntities = entityNamesForEntry(target.id, allEntries);
  const candidateEntities = entityNamesForEntry(candidate.id, allEntries);
  const entityOverlap = jaccard(targetEntities, candidateEntities);
  if (entityOverlap > 0) {
    score += entityOverlap * WEIGHTS.entities;
    reasons.push("entities");
  }

  const keywordOverlap = jaccard(
    extractKeywords(target.transcript),
    extractKeywords(candidate.transcript),
  );
  if (keywordOverlap > 0) {
    score += keywordOverlap * WEIGHTS.keywords;
    reasons.push("keywords");
  }

  const concernOverlap = jaccard(
    extractKeywords(concernText(target)),
    extractKeywords(concernText(candidate)),
  );
  if (concernOverlap > 0) {
    score += concernOverlap * WEIGHTS.concern;
    reasons.push("concern");
  }

  const recommendationOverlap = jaccard(
    extractKeywords(recommendationText(target)),
    extractKeywords(recommendationText(candidate)),
  );
  if (recommendationOverlap > 0) {
    score += recommendationOverlap * WEIGHTS.recommendation;
    reasons.push("recommendation");
  }

  const daysApart = daysBetweenKeys(
    toDayKey(candidate.createdAt),
    toDayKey(target.createdAt),
  );

  return {
    entry: candidate,
    score: Math.round(score * 10) / 10,
    reasons,
    daysApart,
  };
}

function toRelatedReflection(pair: ScoredPair): RelatedReflection {
  return {
    entry: pair.entry,
    score: pair.score,
    matchReasons: pair.reasons,
    snippet: getEntryPreviewLine(pair.entry.reflection),
    daysApart: pair.daysApart,
  };
}

function buildRepeatedConcerns(
  target: JournalEntry,
  prior: JournalEntry[],
): RepeatedConcern[] {
  const counts = new Map<string, { count: number; lastBeforeTarget: string | null }>();

  const addLabel = (raw: string, entryDay: string, isTarget: boolean) => {
    const label = raw.trim();
    if (!label || label.length < 3) return;
    const key = normalizeText(label);
    const row = counts.get(key) ?? { count: 0, lastBeforeTarget: null };
    row.count += 1;
    if (!isTarget) row.lastBeforeTarget = entryDay;
    counts.set(key, row);
  };

  for (const entry of prior) {
    for (const theme of entry.reflection.recurringThemes) {
      addLabel(theme, toDayKey(entry.createdAt), false);
    }
    addLabel(entry.reflection.hiddenConcern, toDayKey(entry.createdAt), false);
    addLabel(entry.reflection.avoidedOrVagueArea ?? "", toDayKey(entry.createdAt), false);
  }

  for (const theme of target.reflection.recurringThemes) {
    addLabel(theme, toDayKey(target.createdAt), true);
  }
  addLabel(target.reflection.hiddenConcern, toDayKey(target.createdAt), true);
  addLabel(target.reflection.avoidedOrVagueArea ?? "", toDayKey(target.createdAt), true);

  const targetDay = toDayKey(target.createdAt);

  return [...counts.entries()]
    .filter(([, row]) => row.count >= 2)
    .map(([key, row]) => ({
      label: key,
      count: row.count,
      daysSincePrevious: row.lastBeforeTarget
        ? daysBetweenKeys(row.lastBeforeTarget, targetDay)
        : null,
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);
}

function buildRecurringEmotionalPatterns(
  target: JournalEntry,
  related: RelatedReflection[],
): RecurringEmotionalPattern[] {
  const moodCounts = new Map<string, { count: number; moods: Set<string> }>();

  const register = (entry: JournalEntry) => {
    for (const theme of entry.reflection.recurringThemes) {
      const key = normalizeText(theme);
      if (!key) continue;
      const row = moodCounts.get(key) ?? { count: 0, moods: new Set<string>() };
      row.count += 1;
      row.moods.add(normalizeText(entry.reflection.mood));
      moodCounts.set(key, row);
    }
  };

  register(target);
  for (const item of related) register(item.entry);

  return [...moodCounts.entries()]
    .filter(([, row]) => row.count >= 2)
    .map(([label, row]) => ({
      label,
      count: row.count,
      moods: [...row.moods],
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 4);
}

function buildLastMentioned(
  target: JournalEntry,
  prior: JournalEntry[],
): LastMentionedReference[] {
  const refs: LastMentionedReference[] = [];
  const targetDay = toDayKey(target.createdAt);
  const targetThemes = themeSet(target);

  for (const theme of targetThemes) {
    const previous = prior
      .filter((e) => themeSet(e).has(theme))
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
    if (!previous) continue;
    const daysAgo = daysBetweenKeys(toDayKey(previous.createdAt), targetDay);
    if (daysAgo <= 0) continue;
    refs.push({
      label: theme,
      kind: "theme",
      daysAgo,
      previousEntryId: previous.id,
    });
  }

  const concern = normalizeText(concernText(target));
  if (concern.length >= 8) {
    const previous = prior
      .filter((e) => {
        const overlap = jaccard(
          extractKeywords(concernText(e)),
          extractKeywords(concern),
        );
        return overlap >= 0.2;
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
    if (previous) {
      const daysAgo = daysBetweenKeys(toDayKey(previous.createdAt), targetDay);
      if (daysAgo > 0) {
        refs.push({
          label: concern.slice(0, 60),
          kind: "concern",
          daysAgo,
          previousEntryId: previous.id,
        });
      }
    }
  }

  const allEntries = getEntries();
  const snapshot = buildEntityMemoryFromEntries(allEntries);
  const targetEntities = entityNamesForEntry(target.id, allEntries);

  for (const entity of [...snapshot.people, ...snapshot.topics, ...snapshot.concerns]) {
    if (!targetEntities.has(normalizeText(entity.name))) continue;
    if (entity.mentionCount < 2) continue;

    const previousId = entity.entryIds
      .filter((id) => id !== target.id)
      .map((id) => prior.find((e) => e.id === id))
      .filter(Boolean)
      .sort(
        (a, b) =>
          new Date(b!.createdAt).getTime() - new Date(a!.createdAt).getTime(),
      )[0];

    if (!previousId) continue;
    const daysAgo = daysBetweenKeys(toDayKey(previousId.createdAt), targetDay);
    if (daysAgo <= 0) continue;

    refs.push({
      label: entity.name,
      kind: "entity",
      daysAgo,
      previousEntryId: previousId.id,
    });
  }

  return refs
    .sort((a, b) => a.daysAgo - b.daysAgo)
    .slice(0, 6);
}

function buildMentionAgainLines(
  repeatedConcerns: RepeatedConcern[],
  lastMentioned: LastMentionedReference[],
): string[] {
  const lines: string[] = [];

  for (const concern of repeatedConcerns) {
    if (concern.daysSincePrevious !== null && concern.daysSincePrevious > 0) {
      lines.push(
        `You mentioned "${concern.label}" again after ${concern.daysSincePrevious} day${concern.daysSincePrevious === 1 ? "" : "s"}.`,
      );
    }
  }

  for (const ref of lastMentioned.slice(0, 3)) {
    const prefix =
      ref.kind === "entity"
        ? ref.label
        : `"${ref.label.length > 48 ? `${ref.label.slice(0, 48)}…` : ref.label}"`;
    const line = `You mentioned ${prefix} again after ${ref.daysAgo} day${ref.daysAgo === 1 ? "" : "s"}.`;
    if (!lines.includes(line)) lines.push(line);
  }

  return lines.slice(0, 4);
}

function buildPatternCountLines(
  repeatedConcerns: RepeatedConcern[],
  patterns: RecurringEmotionalPattern[],
): string[] {
  const lines: string[] = [];

  for (const concern of repeatedConcerns.slice(0, 3)) {
    if (concern.count >= 2) {
      lines.push(
        `"${concern.label}" appeared ${concern.count} time${concern.count === 1 ? "" : "s"} across your reflections.`,
      );
    }
  }

  for (const pattern of patterns.slice(0, 2)) {
    lines.push(
      `This pattern appeared ${pattern.count} time${pattern.count === 1 ? "" : "s"} — often with a ${pattern.moods[0] ?? "similar"} tone.`,
    );
  }

  return lines.slice(0, 4);
}

export function buildMemoryContinuityReport(
  target: JournalEntry,
  entries: JournalEntry[] = getEntries(),
): MemoryContinuityReport {
  const prior = entries
    .filter((e) => e.id !== target.id && new Date(e.createdAt) < new Date(target.createdAt))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  if (prior.length === 0) {
    return {
      mentionAgainLines: [],
      patternCountLines: [],
      relatedReflections: [],
      repeatedConcerns: [],
      recurringEmotionalPatterns: [],
      similarFromPreviousWeeks: [],
      lastMentioned: [],
      hasData: false,
    };
  }

  const scored = prior
    .map((candidate) => scorePair(target, candidate))
    .filter((pair) => pair.score >= MIN_SCORE)
    .sort((a, b) => b.score - a.score || b.daysApart - a.daysApart);

  const relatedReflections = scored.slice(0, MAX_RELATED).map(toRelatedReflection);

  const targetWeek = startOfWeekKey(toDayKey(target.createdAt));
  const similarFromPreviousWeeks = scored
    .filter(
      (pair) =>
        startOfWeekKey(toDayKey(pair.entry.createdAt)) !== targetWeek &&
        pair.daysApart >= 7,
    )
    .slice(0, MAX_PREVIOUS_WEEKS)
    .map(toRelatedReflection);

  const repeatedConcerns = buildRepeatedConcerns(target, prior);
  const recurringEmotionalPatterns = buildRecurringEmotionalPatterns(
    target,
    relatedReflections,
  );
  const lastMentioned = buildLastMentioned(target, prior);
  const mentionAgainLines = buildMentionAgainLines(repeatedConcerns, lastMentioned);
  const patternCountLines = buildPatternCountLines(
    repeatedConcerns,
    recurringEmotionalPatterns,
  );

  const hasData =
    relatedReflections.length > 0 ||
    repeatedConcerns.length > 0 ||
    recurringEmotionalPatterns.length > 0 ||
    similarFromPreviousWeeks.length > 0 ||
    lastMentioned.length > 0 ||
    mentionAgainLines.length > 0 ||
    patternCountLines.length > 0;

  return {
    mentionAgainLines,
    patternCountLines,
    relatedReflections,
    repeatedConcerns,
    recurringEmotionalPatterns,
    similarFromPreviousWeeks,
    lastMentioned,
    hasData,
  };
}
