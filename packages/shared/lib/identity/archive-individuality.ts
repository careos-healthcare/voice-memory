import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import {
  buildLanguageFingerprint,
  directCount,
  hedgeCount,
  MIN_FINGERPRINT_ENTRIES,
} from "@/lib/memory/language-fingerprint";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ArchiveIndividualityProfile,
  IndividualityStyleBand,
} from "@/types/archive-individuality";

const PRODUCT_DEFAULT_PHRASES = [
  "sound different",
  "heavier stretch",
  "before things settled",
  "returned here",
  "settled down",
  "you sound",
  "changed later",
];

function bandFromValue(value: number, low: number, high: number): IndividualityStyleBand {
  if (value <= low) return "sparse";
  if (value >= high) return "dense";
  return "moderate";
}

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s']/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 3);
}

function uniqueTokens(entries: JournalEntry[]): number {
  const set = new Set<string>();
  for (const entry of entries) {
    for (const token of tokenize(entry.transcript)) set.add(token);
  }
  return set.size;
}

function themeCount(entries: JournalEntry[]): number {
  const themes = new Set<string>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) themes.add(theme.toLowerCase());
  }
  return themes.size;
}

function observationDensity(entries: JournalEntry[]): IndividualityStyleBand {
  const withObs = entries.filter(
    (e) =>
      (e.reflection.patternObservations?.length ?? 0) > 0 ||
      Boolean(e.reflection.concreteObservation?.trim()),
  ).length;
  const ratio = entries.length > 0 ? withObs / entries.length : 0;
  return bandFromValue(ratio, 0.25, 0.65);
}

function intensitySpread(entries: JournalEntry[]): number {
  if (entries.length < 2) return 0;
  const values = entries.map((e) => e.reflection.emotionalIntensity);
  const min = Math.min(...values);
  const max = Math.max(...values);
  return Math.round((max - min) * 10) / 10;
}

function computeUniquenessScore(
  entries: JournalEntry[],
  fingerprint: ReturnType<typeof buildLanguageFingerprint>,
): number {
  if (entries.length === 0) return 0;

  const vocab = uniqueTokens(entries);
  const themes = themeCount(entries);
  const hedgeDirect =
    fingerprint && fingerprint.avgDirect > 0
      ? fingerprint.avgHedge / fingerprint.avgDirect
      : 1;

  let defaultOverlap = 0;
  const callbackTexts = entries
    .flatMap((e) => [
      e.reflection.exactLanguagePattern,
      e.reflection.concreteObservation,
      e.transcript.slice(0, 200),
    ])
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  for (const phrase of PRODUCT_DEFAULT_PHRASES) {
    if (callbackTexts.includes(phrase)) defaultOverlap += 1;
  }

  return Math.min(
    100,
    Math.round(
      Math.min(vocab, 120) * 0.35 +
        themes * 8 +
        (fingerprint ? Math.abs(hedgeDirect - 1) * 12 : 0) +
        (fingerprint?.medianEntryGap ?? 0) * 2 -
        defaultOverlap * 8,
    ),
  );
}

/** Lightweight archive individuality profile — internal surfacing restraint only. */
export function buildArchiveIndividualityProfile(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveIndividualityProfile {
  const fingerprint = buildLanguageFingerprint(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const sequencing = buildRevisitSequencingReport();
  const loopOpt = buildLoopOptimizationReport(entries);

  const vocabTokens = uniqueTokens(entries);
  const themes = themeCount(entries);
  const vocabDiversity = Math.min(
    100,
    Math.round(vocabTokens * 0.6 + themes * 10),
  );

  const avgHedge = fingerprint?.avgHedge ?? roundAvg(entries.map(hedgeCount));
  const avgDirect = fingerprint?.avgDirect ?? roundAvg(entries.map(directCount));
  const hedgeDirectRatio =
    avgDirect > 0 ? Math.round((avgHedge / avgDirect) * 10) / 10 : avgHedge;

  const certaintyBand: ArchiveIndividualityProfile["namingStyle"]["certaintyBand"] =
    hedgeDirectRatio >= 1.4 ? "hedged" : hedgeDirectRatio <= 0.6 ? "direct" : "mixed";

  const pacingBand = bandFromValue(
    fingerprint?.medianEntryGap ?? 0,
    3,
    10,
  );

  const followupStarted = loopOpt.topContinuationPrompts.reduce((s, r) => s + r.started, 0);
  const followupCompleted = loopOpt.topContinuationPrompts.reduce((s, r) => s + r.completed, 0);
  const continuationBand = bandFromValue(followupCompleted, 0, 4);

  const densityTolerance = Math.min(
    100,
    Math.round(
      (silence.sessionNoteCount <= 2 ? 70 : 40) +
        (silence.weakNoteSuppressed ? 15 : 0) +
        (sequencing.revisitFatigueActive ? -20 : 10),
    ),
  );

  const uniquenessScore = computeUniquenessScore(entries, fingerprint);

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length >= MIN_FINGERPRINT_ENTRIES,
    entryCount: entries.length,
    reflectionStyle: {
      avgIntensity: fingerprint?.avgIntensity ?? roundAvg(entries.map((e) => e.reflection.emotionalIntensity)),
      intensitySpread: intensitySpread(entries),
      observationDensity: observationDensity(entries),
    },
    pacingStyle: {
      medianEntryGapDays: fingerprint?.medianEntryGap ?? 0,
      typicalRecoveryDays: fingerprint?.typicalRecoveryDays ?? 0,
      band: pacingBand,
    },
    silenceRhythm: {
      ignoredCooldownActive: silence.ignoredCooldownActive,
      sessionNoteTolerance: silence.sessionNoteCount,
      weakNoteSuppressed: silence.weakNoteSuppressed,
    },
    emotionalVocabulary: {
      uniqueTokenCount: vocabTokens,
      themeCount: themes,
      diversityScore: vocabDiversity,
    },
    namingStyle: {
      avgHedge,
      avgDirect,
      certaintyBand,
    },
    revisitStyle: {
      fatigueScore: sequencing.fatigueScore,
      recommendedSpacingDays: sequencing.recommendedSpacingDays,
      revisitFatigueActive: sequencing.revisitFatigueActive,
    },
    continuationStyle: {
      followupStarted,
      followupCompleted,
      continuationBand,
    },
    certaintyStyle: {
      hedgeDirectRatio,
      band: certaintyBand,
    },
    emotionalDensityTolerance: {
      score: densityTolerance,
      band: bandFromValue(densityTolerance, 35, 70),
    },
    uniquenessScore,
  };
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

export function profileFingerprintSummary(profile: ArchiveIndividualityProfile): string {
  return [
    profile.namingStyle.certaintyBand,
    profile.pacingStyle.band,
    profile.reflectionStyle.observationDensity,
    String(profile.emotionalVocabulary.diversityScore),
    String(profile.uniquenessScore),
  ].join("|");
}
