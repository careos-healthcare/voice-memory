import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { detectAllContradictions } from "@/lib/patterns/contradictions";
import { buildContinuityReport } from "@/lib/patterns/continuity-engine";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { formatEntryDate } from "@/lib/utils";
import type {
  CalmnessReport,
  CalmnessScope,
  CalmObservation,
  IdentityFrame,
  MemoryLandmark,
  ReflectiveSilence,
} from "@/types/calmness";
import { IDENTITY_FRAME_LABELS } from "@/types/calmness";
import type { JournalEntry } from "@/types/journal";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const CERTAINTY_RE = /\b(i know|i will|definitely|clearly|for sure|decided)\b/gi;
const FUTURE_RE = /\b(hope|hopeful|plan|planning|looking forward|next week|tomorrow)\b/gi;
const LIGHT_MOODS = new Set(["calm", "hopeful", "relieved", "grounded", "steady", "content"]);
const MIN_SHOW = 55;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function stdDev(values: number[]): number {
  if (values.length < 2) return 0;
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  const variance =
    values.reduce((sum, v) => sum + (v - avg) ** 2, 0) / (values.length - 1);
  return Math.sqrt(variance);
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function filterScope(entries: JournalEntry[], scope: CalmnessScope): JournalEntry[] {
  if (scope === "archive" || scope === "entry") return entries;
  const days = scope === "weekly" ? 7 : 30;
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return entries.filter((e) => toDayKey(e.createdAt) >= cutoff);
}

function computeCalmnessScore(sorted: JournalEntry[]): number {
  if (sorted.length < 2) return 50;

  const recent = sorted.slice(-Math.min(6, sorted.length));
  const prior = sorted.slice(
    Math.max(0, sorted.length - 12),
    Math.max(0, sorted.length - 6),
  );

  let score = 50;

  if (prior.length >= 2) {
    const recentAvg = roundAvg(recent.map((e) => e.reflection.emotionalIntensity));
    const priorAvg = roundAvg(prior.map((e) => e.reflection.emotionalIntensity));
    if (recentAvg <= priorAvg - 0.8) score += 18;
    else if (recentAvg >= priorAvg + 0.8) score -= 12;
  }

  const hedgeRecent =
    recent.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / recent.length;
  const hedgePrior =
    prior.length >= 2
      ? prior.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / prior.length
      : hedgeRecent;
  if (hedgeRecent <= hedgePrior - 0.4) score += 12;
  if (hedgeRecent >= hedgePrior + 0.5) score -= 8;

  const certRecent = recent.reduce((n, e) => n + countMatches(e.transcript, CERTAINTY_RE), 0);
  const certPrior = prior.reduce((n, e) => n + countMatches(e.transcript, CERTAINTY_RE), 0);
  if (certRecent > certPrior) score += 8;

  const lightShare =
    recent.filter((e) => LIGHT_MOODS.has(e.reflection.mood.toLowerCase())).length /
    recent.length;
  if (lightShare >= 0.5) score += 10;

  const volRecent = stdDev(recent.map((e) => e.reflection.emotionalIntensity));
  const volPrior =
    prior.length >= 3 ? stdDev(prior.map((e) => e.reflection.emotionalIntensity)) : volRecent;
  if (volRecent <= volPrior - 0.5) score += 10;

  const contradictions = detectAllContradictions(sorted);
  const recentIds = new Set(recent.map((e) => e.id));
  const recentContradictions = contradictions.filter((c) =>
    c.entryIds.some((id) => recentIds.has(id)),
  ).length;
  if (recentContradictions === 0 && contradictions.length > 0) score += 6;

  return Math.min(100, Math.max(0, Math.round(score)));
}

function detectIntensityCalm(sorted: JournalEntry[]): CalmObservation | null {
  if (sorted.length < 4) return null;

  const recent = sorted.slice(-14);
  const mid = Math.floor(recent.length / 2);
  const early = recent.slice(0, mid);
  const late = recent.slice(mid);
  const earlyAvg = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
  const lateAvg = roundAvg(late.map((e) => e.reflection.emotionalIntensity));

  if (lateAvg > earlyAvg - 0.8) return null;

  const days = daysBetweenKeys(
    toDayKey(early[0].createdAt),
    toDayKey(late[late.length - 1].createdAt),
  );
  const windowLabel = days <= 10 ? "the last week or so" : "the last 2 weeks";

  return {
    id: "calm-lighter",
    text: "You sound lighter lately.",
    detail: `Average intensity moved from ${earlyAvg}/10 to ${lateAvg}/10 over ${windowLabel}.`,
    frame: "what_calmer",
    kind: "calmness",
    confidence: 58 + Math.round((earlyAvg - lateAvg) * 4),
    entryIds: late.map((e) => e.id),
  };
}

function detectDirectLanguage(sorted: JournalEntry[]): CalmObservation | null {
  if (sorted.length < 4) return null;

  const mid = Math.floor(sorted.length / 2);
  const early = sorted.slice(0, mid);
  const late = sorted.slice(mid);
  const hedgeEarly =
    early.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / early.length;
  const hedgeLate =
    late.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / late.length;

  if (hedgeLate >= hedgeEarly - 0.3) return null;

  const days = daysBetweenKeys(
    toDayKey(early[0].createdAt),
    toDayKey(late[late.length - 1].createdAt),
  );
  const windowLabel = days <= 14 ? "the last 2 weeks" : "recent entries";

  return {
    id: "calm-direct",
    text: `Your language became more direct over ${windowLabel}.`,
    detail: "Fewer hedging phrases like \"maybe\" and \"I guess\" in your recent words.",
    frame: "what_clearer",
    kind: "calmness",
    confidence: 56 + Math.round((hedgeEarly - hedgeLate) * 8),
    entryIds: late.slice(-4).map((e) => e.id),
  };
}

function detectThemeCalm(sorted: JournalEntry[]): CalmObservation[] {
  const results: CalmObservation[] = [];
  const themeMap = new Map<string, { early: number[]; late: number[]; ids: string[] }>();

  const mid = Math.floor(sorted.length / 2);
  for (const entry of sorted) {
    const isLate = sorted.indexOf(entry) >= mid;
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const row = themeMap.get(key) ?? { early: [], late: [], ids: [] };
      if (isLate) row.late.push(entry.reflection.emotionalIntensity);
      else row.early.push(entry.reflection.emotionalIntensity);
      row.ids.push(entry.id);
      themeMap.set(key, row);
    }
  }

  for (const [theme, row] of themeMap.entries()) {
    if (row.early.length < 2 || row.late.length < 2) continue;
    const earlyAvg = roundAvg(row.early);
    const lateAvg = roundAvg(row.late);
    if (lateAvg <= earlyAvg - 1) {
      results.push({
        id: `calm-theme-${theme}`,
        text: `You mention ${theme} with less tension now.`,
        detail: `Around ${earlyAvg}/10 earlier · ~${lateAvg}/10 recently.`,
        frame: "what_calmer",
        kind: "calmness",
        confidence: 57 + Math.round((earlyAvg - lateAvg) * 3),
        entryIds: row.ids.slice(-4),
      });
    }
  }

  return results.sort((a, b) => b.confidence - a.confidence).slice(0, 2);
}

function detectSmallEvolution(sorted: JournalEntry[]): CalmObservation[] {
  const results: CalmObservation[] = [];
  const phrases = buildPhraseMemory(sorted);

  for (const phrase of phrases.filter((p) => p.count >= 3)) {
    const last = phrase.occurrences[phrase.occurrences.length - 1];
    const daysSince = daysBetweenKeys(last.dateKey, toDayKey(new Date().toISOString()));
    if (daysSince >= 7) {
      results.push({
        id: `evo-stopped-${phrase.phrase}`,
        text: `You stopped using "${phrase.phrase}" after ${last.dateLabel.split(",")[0] ?? "a while ago"}.`,
        kind: "small_evolution",
        confidence: 56 + phrase.count,
        entryIds: phrase.entryIds,
        quote: phrase.phrase,
      });
    }
  }

  if (sorted.length >= 5) {
    const intensities = sorted.map((e) => e.reflection.emotionalIntensity);
    let spikeRecoveries = 0;
    for (let i = 1; i < intensities.length - 1; i += 1) {
      if (intensities[i] >= 7 && intensities[i + 1] <= intensities[i] - 2) {
        spikeRecoveries += 1;
      }
    }
    if (spikeRecoveries >= 2) {
      results.push({
        id: "evo-shorter-spirals",
        text: "Anxious spikes seem to pass faster than they used to.",
        detail: "High-intensity entries are followed by calmer ones more quickly.",
        frame: "what_calmer",
        kind: "small_evolution",
        confidence: 54 + spikeRecoveries * 4,
        entryIds: sorted.slice(-6).map((e) => e.id),
      });
    }
  }

  const mid = Math.floor(sorted.length / 2);
  const futureEarly = sorted
    .slice(0, mid)
    .reduce((n, e) => n + countMatches(e.transcript, FUTURE_RE), 0);
  const futureLate = sorted
    .slice(mid)
    .reduce((n, e) => n + countMatches(e.transcript, FUTURE_RE), 0);
  if (futureLate > futureEarly + 1) {
    results.push({
      id: "evo-future-language",
      text: "More forward-looking language in recent entries.",
      detail: "Words like \"plan\", \"hope\", and \"next week\" show up more often lately.",
      frame: "what_changed",
      kind: "small_evolution",
      confidence: 53 + futureLate - futureEarly,
      entryIds: sorted.slice(mid).filter((e) => FUTURE_RE.test(e.transcript)).map((e) => e.id).slice(0, 4),
    });
  }

  if (sorted.length >= 6) {
    const earlyVol = stdDev(sorted.slice(0, mid).map((e) => e.reflection.emotionalIntensity));
    const lateVol = stdDev(sorted.slice(mid).map((e) => e.reflection.emotionalIntensity));
    if (lateVol <= earlyVol - 0.6) {
      results.push({
        id: "evo-less-volatile",
        text: "Your emotional tone swings less from entry to entry.",
        kind: "small_evolution",
        confidence: 55,
        entryIds: sorted.slice(mid).map((e) => e.id).slice(-4),
      });
    }
  }

  return results.filter((r) => r.confidence >= MIN_SHOW).slice(0, 4);
}

function detectLandmarks(sorted: JournalEntry[]): MemoryLandmark[] {
  const landmarks: MemoryLandmark[] = [];

  const themeIntensities = new Map<string, Array<{ entry: JournalEntry; intensity: number }>>();
  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const list = themeIntensities.get(key) ?? [];
      list.push({ entry, intensity: entry.reflection.emotionalIntensity });
      themeIntensities.set(key, list);
    }
  }

  for (const [theme, rows] of themeIntensities.entries()) {
    if (rows.length < 3) continue;
    const peak = rows.reduce((best, r) => (r.intensity > best.intensity ? r : best));
    if (peak.intensity >= 6) {
      landmarks.push({
        id: `landmark-peak-${theme}`,
        text: `This was when ${theme} pressure peaked.`,
        detail: `${peak.intensity}/10 on ${formatEntryDate(peak.entry.createdAt)}.`,
        dateLabel: formatEntryDate(peak.entry.createdAt),
        entryIds: [peak.entry.id],
        confidence: 58 + peak.intensity,
      });
    }

    const moneyCalm = theme.includes("money")
      ? rows.filter((r) => LIGHT_MOODS.has(r.entry.reflection.mood.toLowerCase()))
      : [];
    if (moneyCalm.length > 0) {
      const first = moneyCalm[0];
      landmarks.push({
        id: "landmark-money-calm",
        text: "This was the first calmer conversation about money.",
        detail: formatEntryDate(first.entry.createdAt),
        dateLabel: formatEntryDate(first.entry.createdAt),
        entryIds: [first.entry.id],
        confidence: 56,
      });
    }
  }

  for (const phrase of buildPhraseMemory(sorted).filter((p) => p.count >= 3)) {
    const last = phrase.occurrences[phrase.occurrences.length - 1];
    const daysSince = daysBetweenKeys(last.dateKey, toDayKey(new Date().toISOString()));
    if (daysSince >= 10) {
      const month = new Intl.DateTimeFormat("en-US", { month: "long" }).format(
        new Date(last.dateKey + "T12:00:00"),
      );
      landmarks.push({
        id: `landmark-fade-${phrase.phrase}`,
        text: `You stopped mentioning "${phrase.phrase}" after ${month}.`,
        dateLabel: last.dateLabel,
        entryIds: phrase.entryIds.slice(-2),
        confidence: 55 + phrase.count,
      });
    }
  }

  return landmarks
    .filter((l) => l.confidence >= MIN_SHOW)
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 5);
}

function mapContinuityToObservations(
  sorted: JournalEntry[],
  scope: CalmnessScope,
  entryId?: string,
): CalmObservation[] {
  const continuityScope =
    scope === "weekly" ? "weekly" : scope === "entry" ? "entry" : "archive";
  const continuity = buildContinuityReport(sorted, {
    scope: continuityScope,
    entryId,
    limit: 12,
  });

  const mapped: CalmObservation[] = [];

  for (const item of continuity.items) {
    let frame: IdentityFrame | undefined;
    switch (item.surface) {
      case "calmer":
        frame = "what_calmer";
        break;
      case "disappeared":
        frame = "what_faded";
        break;
      case "reappeared":
      case "emerged":
        frame = "what_changed";
        break;
      case "changed_over_time":
        frame = "what_changed";
        break;
      case "more_intense":
        frame = "what_changed";
        break;
    }

    mapped.push({
      id: item.id,
      text: item.title,
      detail: item.detail,
      frame,
      kind: "continuity",
      confidence: item.confidence,
      entryIds: item.entryIds,
      quote: item.evidence[0]?.phrase,
    });
  }

  for (const item of [...continuity.changeMoments, ...continuity.beforeAfter]) {
    mapped.push({
      id: item.id,
      text: item.title,
      detail: item.detail,
      frame: "what_changed",
      kind: "continuity",
      confidence: item.confidence,
      entryIds: item.entryIds,
      quote: item.evidence[0]?.phrase,
    });
  }

  const phraseCounts = new Map<string, number>();
  for (const entry of sorted) {
    const quote = entry.reflection.exactLanguagePattern?.trim();
    if (quote) phraseCounts.set(quote, (phraseCounts.get(quote) ?? 0) + 1);
  }
  for (const [phrase, count] of phraseCounts.entries()) {
    if (count >= 2) {
      mapped.push({
        id: `repeat-${phrase.slice(0, 12)}`,
        text: `"${phrase.slice(0, 60)}${phrase.length > 60 ? "…" : ""}" kept showing up.`,
        frame: "what_repeated",
        kind: "continuity",
        confidence: 50 + count * 5,
        entryIds: sorted.filter((e) => e.reflection.exactLanguagePattern === phrase).map((e) => e.id),
        quote: phrase,
      });
    }
  }

  return mapped.filter((o) => o.confidence >= MIN_SHOW);
}

function buildSilence(observations: CalmObservation[]): ReflectiveSilence | undefined {
  const top = observations[0];
  if (!top || top.confidence < 62) return undefined;

  if (observations.length <= 2) {
    if (top.quote) {
      return {
        mode: "quote",
        primary: `"${top.quote.slice(0, 120)}"`,
        secondary: top.text,
        entryId: top.entryIds[0],
      };
    }
    return { mode: "sentence", primary: top.text, entryId: top.entryIds[0] };
  }

  const second = observations[1];
  if (top.confidence >= 68 && second && top.frame === "what_calmer" && second.frame === "what_clearer") {
    return {
      mode: "contrast",
      primary: top.text,
      secondary: second.text,
    };
  }

  return undefined;
}

function emptyFrames(): Record<IdentityFrame, CalmObservation[]> {
  return {
    what_changed: [],
    what_repeated: [],
    what_faded: [],
    what_calmer: [],
    what_clearer: [],
  };
}

export interface CalmnessOptions {
  scope?: CalmnessScope;
  entryId?: string;
  limit?: number;
}

/** Build calm longitudinal understanding — observational, restrained, evidence-gated. */
export function buildCalmnessReport(
  entries: JournalEntry[],
  options: CalmnessOptions = {},
): CalmnessReport {
  const scope = options.scope ?? "archive";
  const limit = options.limit ?? 3;

  const scoped = filterScope(entries, scope);
  const sorted = sortedEntries(scoped);

  if (sorted.length === 0) {
    return {
      score: 50,
      observations: [],
      landmarks: [],
      smallEvolution: [],
      byFrame: emptyFrames(),
      hasData: false,
      generatedAt: new Date().toISOString(),
      scope,
    };
  }

  const score = computeCalmnessScore(sorted);

  const calmSignals = [
    detectIntensityCalm(sorted),
    detectDirectLanguage(sorted),
    ...detectThemeCalm(sorted),
  ].filter((o): o is CalmObservation => o !== null && o.confidence >= MIN_SHOW);

  const smallEvolution = detectSmallEvolution(sorted);
  const landmarks = detectLandmarks(sorted);
  const continuityObs = mapContinuityToObservations(sorted, scope, options.entryId);

  const pool = [...calmSignals, ...smallEvolution, ...continuityObs]
    .sort((a, b) => b.confidence - a.confidence)
    .filter((o) => o.confidence >= MIN_SHOW);

  const seen = new Set<string>();
  const observations: CalmObservation[] = [];
  for (const obs of pool) {
    const key = obs.text.slice(0, 48);
    if (seen.has(key)) continue;
    seen.add(key);
    observations.push(obs);
    if (observations.length >= limit) break;
  }

  const byFrame = emptyFrames();
  for (const obs of [...observations, ...pool]) {
    if (obs.frame && byFrame[obs.frame].length < 2) {
      if (!byFrame[obs.frame].some((x) => x.id === obs.id)) {
        byFrame[obs.frame].push(obs);
      }
    }
  }

  const silence = buildSilence(observations);

  return {
    score,
    observations,
    landmarks,
    smallEvolution,
    byFrame,
    silence,
    hasData: observations.length > 0 || landmarks.length > 0,
    generatedAt: new Date().toISOString(),
    scope,
  };
}

export function getCalmnessForEntry(
  entries: JournalEntry[],
  entryId: string,
): CalmnessReport {
  return buildCalmnessReport(entries, { scope: "entry", entryId, limit: 3 });
}

export function getMonthlyReflection(entries: JournalEntry[]): CalmnessReport {
  return buildCalmnessReport(entries, { scope: "monthly", limit: 5 });
}

export { IDENTITY_FRAME_LABELS };
