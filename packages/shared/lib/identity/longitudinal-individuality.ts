import {
  buildArchiveIndividualityProfile,
  profileFingerprintSummary,
} from "@/lib/identity/archive-individuality";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { assessVoiceTexture } from "@/lib/identity/voice-texture";
import { directCount, hedgeCount, buildLanguageFingerprint } from "@/lib/memory/language-fingerprint";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { LongitudinalIndividualityReport } from "@/types/archive-individuality";

function sorted(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function halfUniqueness(entries: JournalEntry[]): number {
  if (entries.length < 4) return 0;
  return buildArchiveIndividualityProfile(entries).uniquenessScore;
}

/** Longitudinal protection — archives should become more unique over time, not standardized. */
export function buildLongitudinalIndividualityReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): LongitudinalIndividualityReport {
  const sortedEntries = sorted(entries);
  const mid = Math.floor(sortedEntries.length / 2);
  const early = sortedEntries.slice(0, Math.max(mid, 2));
  const recent = sortedEntries.slice(mid);

  const earlyScore = halfUniqueness(early);
  const recentScore = halfUniqueness(recent);
  const becomingMoreUnique = recentScore > earlyScore + 5;
  const converging = recentScore < earlyScore - 8;

  const signals: LongitudinalIndividualityReport["signals"] = [];

  const earlyFp = buildLanguageFingerprint(early);
  const recentFp = buildLanguageFingerprint(recent.length >= 3 ? recent : sortedEntries);

  if (earlyFp && recentFp) {
    const hedgeShift = recentFp.avgHedge - earlyFp.avgHedge;
    const directShift = recentFp.avgDirect - earlyFp.avgDirect;
    if (Math.abs(hedgeShift) <= 0.3 && Math.abs(directShift) <= 0.3 && sortedEntries.length >= 10) {
      signals.push({
        id: "wording-normalization",
        label: "Wording normalization",
        detail: "Hedge/direct balance flattened over time",
      });
    }
  }

  const dedup = buildCallbackDeduplicationReport(sortedEntries);
  if (dedup.collapsedTemplates.length >= 2) {
    signals.push({
      id: "callback-convergence",
      label: "Callback convergence",
      detail: dedup.collapsedTemplates.join("; "),
    });
  }

  const texture = assessVoiceTexture(sortedEntries);
  if (texture.polishRiskCount > texture.protectedPhraseCount && sortedEntries.length >= 8) {
    signals.push({
      id: "over-cleaned",
      label: "Over-cleaned reflection language",
      detail: `${texture.polishRiskCount} polish risks vs ${texture.protectedPhraseCount} protected phrases`,
    });
  }

  const earlyIntensity = early.map((e) => e.reflection.emotionalIntensity);
  const recentIntensity = recent.map((e) => e.reflection.emotionalIntensity);
  if (earlyIntensity.length >= 3 && recentIntensity.length >= 3) {
    const earlySpread = Math.max(...earlyIntensity) - Math.min(...earlyIntensity);
    const recentSpread = Math.max(...recentIntensity) - Math.min(...recentIntensity);
    if (recentSpread < earlySpread - 1.5) {
      signals.push({
        id: "emotional-simplification",
        label: "Emotional simplification",
        detail: `Intensity spread narrowed (${earlySpread.toFixed(1)} → ${recentSpread.toFixed(1)})`,
      });
    }
  }

  const earlyHedge = early.reduce((s, e) => s + hedgeCount(e), 0) / Math.max(early.length, 1);
  const recentHedge = recent.reduce((s, e) => s + hedgeCount(e), 0) / Math.max(recent.length, 1);
  const earlyDirect = early.reduce((s, e) => s + directCount(e), 0) / Math.max(early.length, 1);
  const recentDirect = recent.reduce((s, e) => s + directCount(e), 0) / Math.max(recent.length, 1);
  if (recentHedge < earlyHedge * 0.6 && recentDirect > earlyDirect * 1.4) {
    signals.push({
      id: "certainty-drift",
      label: "Certainty drift",
      detail: "Recent entries more direct than early archive voice",
    });
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: sortedEntries.length >= 6,
    earlyUniquenessScore: earlyScore,
    recentUniquenessScore: recentScore,
    converging,
    becomingMoreUnique,
    signals,
  };
}

export function longitudinalFingerprint(entries: JournalEntry[]): string {
  const report = buildLongitudinalIndividualityReport(entries);
  const profile = buildArchiveIndividualityProfile(entries);
  return `${profileFingerprintSummary(profile)}:${report.recentUniquenessScore}:${report.converging}`;
}
