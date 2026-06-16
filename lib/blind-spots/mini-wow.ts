import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";
import { buildCostEvidence } from "@/lib/blind-spots/cost-evidence";
import { buildEmergingPatterns } from "@/lib/blind-spots/emerging-patterns";
import { MINI_WOW_COPY } from "@/lib/blind-spots/mini-wow-copy";
import {
  buildInsightScorecard,
  INGREDIENT_LABELS,
} from "@/lib/insights/insight-scorecard";
import {
  computeEvidenceStrength,
  linkedAreasForEntries,
} from "@/lib/blind-spots/blind-spot-ranking";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  buildPatternCandidatesRelaxed,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { formatEntryDate } from "@/lib/utils";
import type { MiniWowClueType, MiniWowReport, MiniWowTier } from "@/types/mini-wow";
import type { BlindSpotEvidenceQuote } from "@/types/blind-spot";
import type { JournalEntry } from "@/types/journal";

const BLOCKED_THEMES = new Set(["general", "other", "misc", "stress", "work"]);

const HEDGE_PHRASES = new Set([
  "maybe",
  "i guess",
  "eventually",
  "sort of",
  "probably",
  "i don't know",
]);

interface ThemeEchoCandidate {
  kind: "theme" | "phrase";
  theme: string;
  entryIds: string[];
  quotes: BlindSpotEvidenceQuote[];
}

type MiniWowCandidate = PatternInsight | ThemeEchoCandidate;

function trimQuote(text: string): string {
  const n = text.replace(/\s+/g, " ").trim();
  return n.length <= 160 ? n : `${n.slice(0, 157)}…`;
}

function eligibleEntries(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function spanDaysForInsight(insight: PatternInsight, entriesById: Map<string, JournalEntry>): number {
  const keys = insight.entryIds
    .map((id) => entriesById.get(id)?.createdAt)
    .filter(Boolean)
    .map((iso) => toDayKey(iso!))
    .sort();
  if (keys.length < 2) return 0;
  return Math.max(0, daysBetweenKeys(keys[0]!, keys[keys.length - 1]!));
}

function quotesFromInsight(
  insight: PatternInsight,
  entriesById: Map<string, JournalEntry>,
): BlindSpotEvidenceQuote[] {
  return insight.evidence
    .filter((e) => e.phrase?.trim())
    .slice(0, 3)
    .map((e) => ({
      entryId: e.entryId,
      dateLabel: e.dateLabel ?? (entriesById.get(e.entryId) ? formatEntryDate(entriesById.get(e.entryId)!.createdAt) : ""),
      quote: trimQuote(e.phrase),
    }));
}

export function findThemeEcho(entries: JournalEntry[]): ThemeEchoCandidate | null {
  const themeMap = new Map<string, string[]>();

  for (const entry of entries) {
    const blob = [
      entry.transcript,
      entry.reflection.exactLanguagePattern ?? "",
      entry.reflection.repeatedSignal ?? "",
    ].join(" ");

    for (const raw of entry.reflection.recurringThemes) {
      const theme = raw.trim().toLowerCase();
      if (theme.length < 5 || BLOCKED_THEMES.has(theme)) continue;
      if (!blob.toLowerCase().includes(theme)) continue;
      const list = themeMap.get(theme) ?? [];
      if (!list.includes(entry.id)) list.push(entry.id);
      themeMap.set(theme, list);
    }
  }

  const ranked = [...themeMap.entries()]
    .filter(([, ids]) => ids.length >= 2)
    .sort((a, b) => b[1].length - a[1].length);

  const best = ranked[0];
  if (!best) return null;

  const [theme, entryIds] = best;
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const quotes = entryIds.slice(0, 2).map((entryId) => {
    const entry = entriesById.get(entryId)!;
    const quote =
      entry.reflection.exactLanguagePattern?.trim() ||
      entry.reflection.repeatedSignal?.trim() ||
      entry.transcript.trim().slice(0, 120);
    return {
      entryId,
      dateLabel: formatEntryDate(entry.createdAt),
      quote: trimQuote(quote),
    };
  });

  if (quotes.every((q) => q.quote.length < 12)) return null;

  return { kind: "theme", theme, entryIds, quotes };
}

export function phraseEchoCandidate(entries: JournalEntry[]): ThemeEchoCandidate | null {
  const phrases = buildPhraseMemory(entries).filter(
    (p) => p.entryIds.length >= 2 && p.count >= 2 && p.phrase.length >= 8,
  );

  const ranked = phrases
    .filter((p) => !(p.category === "linguistic_habit" && HEDGE_PHRASES.has(p.phrase.toLowerCase())))
    .sort((a, b) => b.entryIds.length - a.entryIds.length || b.count - a.count);

  const best = ranked[0];
  if (!best) return null;

  return {
    kind: "phrase",
    theme: best.phrase,
    entryIds: best.entryIds,
    quotes: best.occurrences.slice(0, 2).map((o) => ({
      entryId: o.entryId,
      dateLabel: o.dateLabel,
      quote: trimQuote(o.snippet),
    })),
  };
}

function rankCandidates(entries: JournalEntry[]): MiniWowCandidate | null {
  const themeEcho = findThemeEcho(entries) ?? phraseEchoCandidate(entries);
  const patternCandidates = buildPatternCandidatesRelaxed(entries, { limit: 12 });
  const bestPattern = patternCandidates[0];

  if (!bestPattern) return themeEcho;

  if (!themeEcho) return bestPattern;

  const patternScore =
    bestPattern.specificity.specificityScore + bestPattern.entryIds.length * 4;
  const themeScore = themeEcho.entryIds.length * 5 + (themeEcho.quotes[0]?.quote.length ?? 0) / 10;

  return patternScore >= themeScore ? bestPattern : themeEcho;
}

function isThemeCandidate(candidate: MiniWowCandidate): candidate is ThemeEchoCandidate {
  return "kind" in candidate && (candidate.kind === "theme" || candidate.kind === "phrase");
}

function meetsEchoGate(candidate: MiniWowCandidate): boolean {
  if (isThemeCandidate(candidate)) {
    return candidate.entryIds.length >= 2 && candidate.quotes.length >= 2;
  }
  if (candidate.specificity.isWeakOrGeneric) return false;
  if (candidate.entryIds.length < 2) return false;
  if (candidate.type === "repeated_phrase") {
    return candidate.specificity.specificityScore >= 34;
  }
  return candidate.specificity.specificityScore >= 38;
}

function meetsFormingGate(candidate: MiniWowCandidate): boolean {
  if (isThemeCandidate(candidate)) return candidate.entryIds.length >= 2;
  if (candidate.specificity.isWeakOrGeneric) return false;
  if (candidate.entryIds.length < 2) return false;
  return candidate.specificity.specificityScore >= 40;
}

function meetsPreviewGate(
  candidate: MiniWowCandidate,
  entries: JournalEntry[],
): boolean {
  if (isThemeCandidate(candidate)) {
    return candidate.entryIds.length >= 3;
  }
  if (candidate.specificity.isWeakOrGeneric) return false;
  if (candidate.entryIds.length < 3 && candidate.specificity.specificityScore < 48) {
    return false;
  }

  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const spanDays = spanDaysForInsight(candidate, entriesById);
  const lifeAreas = linkedAreasForEntries(entries, candidate.entryIds);
  const { score, label } = computeEvidenceStrength({
    matchingReflections: candidate.entryIds.length,
    spanDays,
    lifeAreaCount: lifeAreas.length,
    signalBonus: candidate.type === "contradiction" ? 8 : 0,
  });

  if (label === "low") return false;
  return score >= 45 || candidate.specificity.specificityScore >= 50;
}

function resolveTier(
  reflectionCount: number,
  candidate: MiniWowCandidate | null,
  entries: JournalEntry[],
): MiniWowTier {
  if (reflectionCount >= BLIND_SPOT_MIN_REFLECTIONS) return "unlocked";
  if (!candidate || reflectionCount < 2) return "none";
  if (reflectionCount >= 4 && meetsPreviewGate(candidate, entries)) return "preview";
  if (reflectionCount >= 3 && meetsFormingGate(candidate)) return "forming";
  if (reflectionCount >= 2 && meetsEchoGate(candidate)) return "echo";
  return "none";
}

function bodyForCandidate(candidate: MiniWowCandidate, tier: MiniWowTier): string {
  if (isThemeCandidate(candidate)) {
    const label = candidate.theme;
    if (tier === "echo") {
      return `Your recent reflections may echo around “${label}” — worth noticing, not deciding.`;
    }
    if (tier === "forming") {
      return `A possible thread around “${label}” may be forming across ${candidate.entryIds.length} reflections.`;
    }
    return `This preview ties ${candidate.entryIds.length} reflections that mention “${label}”.`;
  }

  const detail = candidate.detail.replace(/\s+/g, " ").trim();
  if (tier === "echo") {
    return detail.length > 0 ? detail : candidate.title;
  }
  if (tier === "forming") {
    return `This may be forming: ${detail.charAt(0).toLowerCase()}${detail.slice(1)}`;
  }
  return detail.length > 0 ? detail : candidate.title;
}

function titleForTier(tier: MiniWowTier): string {
  switch (tier) {
    case "echo":
      return MINI_WOW_COPY.echoTitle;
    case "forming":
      return MINI_WOW_COPY.formingTitle;
    case "preview":
      return MINI_WOW_COPY.previewTitle;
    case "unlocked":
      return MINI_WOW_COPY.unlockedTitle;
    default:
      return "";
  }
}

function confidenceForTier(tier: MiniWowTier): string | undefined {
  if (tier === "forming") return MINI_WOW_COPY.formingConfidence;
  if (tier === "preview") return MINI_WOW_COPY.previewConfidence;
  return undefined;
}

function evidenceForCandidate(
  candidate: MiniWowCandidate | null,
  entries: JournalEntry[],
): BlindSpotEvidenceQuote[] {
  if (!candidate) return [];
  if (isThemeCandidate(candidate)) return candidate.quotes;
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  return quotesFromInsight(candidate, entriesById);
}

function clueTypeForCandidate(candidate: MiniWowCandidate): MiniWowClueType {
  if (isThemeCandidate(candidate)) {
    return candidate.kind === "phrase" ? "repeated_phrase" : "repeated_theme";
  }
  if (candidate.type === "repeated_phrase") return "repeated_phrase";
  return "emerging_pattern";
}

function scorecardIngredientClue(
  candidate: MiniWowCandidate | null,
  entries: JournalEntry[],
): { body: string; clueType: MiniWowClueType } | null {
  if (!candidate) return null;
  const entriesById = new Map(entries.map((e) => [e.id, e]));

  let ingredients;
  if (isThemeCandidate(candidate)) {
    ingredients = {
      crossLifeArea: false,
      contradiction: false,
      costEvidence: false,
      longTimeSpanDays: 0,
      failedPrediction: false,
    };
  } else {
    const spanDays = spanDaysForInsight(candidate, entriesById);
    const lifeAreas = linkedAreasForEntries(entries, candidate.entryIds);
    const costEvidence = Object.values(
      buildCostEvidence(candidate.entryIds, entries),
    ).reduce((s, n) => s + n, 0);
    ingredients = {
      contradiction: candidate.type === "contradiction",
      costEvidence: costEvidence > 0,
      crossLifeArea: lifeAreas.length >= 2,
      longTimeSpanDays: spanDays,
      failedPrediction: false,
    };
  }

  const card = buildInsightScorecard({
    insightId: "mini-wow:early",
    surface: "blind_spot",
    headline: "Early reflection signal",
    sourceIds: isThemeCandidate(candidate) ? candidate.entryIds : candidate.entryIds,
    ingredients,
  });

  const strongest = card.strongestIngredients[0];
  if (!strongest?.present) return null;

  return {
    clueType: "scorecard_ingredient",
    body: MINI_WOW_COPY.scorecardIngredientLead(INGREDIENT_LABELS[strongest.key]),
  };
}

function resolveTierWithFirst(
  reflectionCount: number,
  candidate: MiniWowCandidate | null,
  entries: JournalEntry[],
): MiniWowTier {
  if (reflectionCount === 1) return "first";
  if (reflectionCount >= BLIND_SPOT_MIN_REFLECTIONS) return "unlocked";
  return resolveTier(reflectionCount, candidate, entries);
}

function fallbackEarlyClue(
  eligible: JournalEntry[],
  candidate: MiniWowCandidate | null,
): Pick<MiniWowReport, "title" | "body" | "clueType" | "evidenceQuotes" | "confidenceLabel"> | null {
  const emerging = buildEmergingPatterns(eligible)[0];
  if (emerging) {
    return {
      title: emerging.label,
      body: emerging.hypothesis,
      clueType: "emerging_pattern",
      confidenceLabel: emerging.confidenceLabel,
      evidenceQuotes: emerging.evidenceQuotes,
    };
  }

  const scorecard = scorecardIngredientClue(candidate, eligible);
  if (scorecard) {
    return {
      title: "Possible early signal",
      body: scorecard.body,
      clueType: scorecard.clueType,
      evidenceQuotes: evidenceForCandidate(candidate, eligible),
    };
  }

  return null;
}

function baseReportFields(reflectionCount: number): Pick<
  MiniWowReport,
  "reflectionCount" | "progressLabel" | "panelTitle" | "disclaimer"
> {
  return {
    reflectionCount,
    progressLabel: MINI_WOW_COPY.progressTowardReview(
      Math.min(reflectionCount, BLIND_SPOT_MIN_REFLECTIONS),
    ),
    panelTitle: MINI_WOW_COPY.panelTitle,
    disclaimer: MINI_WOW_COPY.disclaimer,
  };
}

/** Immediate learning signal after each save; extends mini-wow for 1–4 reflections. */
export function buildMiniWowReport(entries: JournalEntry[]): MiniWowReport {
  const eligible = eligibleEntries(entries);
  const reflectionCount = eligible.length;
  const candidate = rankCandidates(eligible);
  const tier = resolveTierWithFirst(reflectionCount, candidate, eligible);
  const base = baseReportFields(reflectionCount);

  if (tier === "first") {
    return {
      ...base,
      tier,
      title: "",
      body: MINI_WOW_COPY.firstReflectionBody,
      clueType: "none",
      evidenceQuotes: [],
      showPanel: true,
    };
  }

  if (tier === "unlocked") {
    return {
      ...base,
      tier,
      progressLabel: MINI_WOW_COPY.progressTowardReview(BLIND_SPOT_MIN_REFLECTIONS),
      title: MINI_WOW_COPY.unlockedTitle,
      body: MINI_WOW_COPY.unlockedBody,
      clueType: "none",
      evidenceQuotes: [],
      showPanel: false,
    };
  }

  if (tier !== "none" && candidate) {
    return {
      ...base,
      tier,
      title: titleForTier(tier),
      body: bodyForCandidate(candidate, tier),
      clueType: clueTypeForCandidate(candidate),
      confidenceLabel: confidenceForTier(tier),
      evidenceQuotes: evidenceForCandidate(candidate, eligible),
      showPanel: true,
    };
  }

  if (reflectionCount >= 2 && reflectionCount < BLIND_SPOT_MIN_REFLECTIONS) {
    const fallback = fallbackEarlyClue(eligible, candidate);
    if (fallback) {
      return {
        ...base,
        tier: "echo",
        title: fallback.title,
        body: fallback.body,
        clueType: fallback.clueType,
        confidenceLabel: fallback.confidenceLabel,
        evidenceQuotes: fallback.evidenceQuotes,
        showPanel: true,
      };
    }
  }

  return {
    ...base,
    tier: "none",
    title: "",
    body: "",
    clueType: "none",
    evidenceQuotes: [],
    showPanel: false,
  };
}

/** Alias for post-save “what we noticed” surfaces. */
export const buildImmediateLearningSignal = buildMiniWowReport;
