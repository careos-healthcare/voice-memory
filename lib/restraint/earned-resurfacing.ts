import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { EarnedResurfacingReport, EarnedResurfacingRow } from "@/types/sacredness-layer";

const BASE_DECAY_PER_SURFACE = 8;
const EARNED_RESURFACE_THRESHOLD = 52;

function decayMultiplier(metrics: {
  revisits: number;
  bookmarks: number;
  copies: number;
  reflections: number;
  surfaces: number;
  dead: boolean;
}): { decay: number; reason: string } {
  let decay = metrics.surfaces * BASE_DECAY_PER_SURFACE;
  let reason = "Exposure decay";

  if (metrics.revisits > 0 || metrics.reflections > 0) {
    decay *= 0.55;
    reason = "Revisit/reflection slows decay";
  }
  if (metrics.bookmarks > 0 || metrics.copies > 0) {
    decay *= 0.45;
    reason = "Bookmark/copy slows decay";
  }
  if (metrics.dead && metrics.surfaces >= 3) {
    decay += 25;
    reason = "Novelty-only fast decay";
  }

  return { decay: Math.round(decay), reason };
}

function earnedScore(
  metrics: {
    revisits: number;
    reflections: number;
    day7Returns: number;
    residueScore: number;
    surfaces: number;
    ignores: number;
  },
  item: { emotionalWeight: number; survival: { emotionalSurvivalScore: number } },
): number {
  let score = item.emotionalWeight * 0.35 + item.survival.emotionalSurvivalScore * 0.35;

  if (metrics.day7Returns > 0) score += 18;
  if (metrics.revisits > 0) score += 12;
  if (metrics.reflections > 0) score += 15;
  if (metrics.surfaces > 0 && metrics.ignores === 0) score += 8;
  if (metrics.surfaces >= 4) score -= metrics.surfaces * 4;

  return Math.min(100, Math.round(score));
}

/** Major callbacks must earn resurfacing — repeated exposure weakens them. */
export function buildEarnedResurfacingReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EarnedResurfacingReport {
  const callbacks = buildCallbackQualityReviewReport(entries);
  const loopOpt = buildLoopOptimizationReport(entries);
  const metricsMap = new Map(loopOpt.topPerforming.concat(loopOpt.deadCallbacks).map((r) => [r.noteId, r]));

  const rows: EarnedResurfacingRow[] = callbacks.items.slice(0, 24).map((item) => {
    const metrics = metricsMap.get(item.id) ?? {
      revisits: item.signals.revisitCount,
      bookmarks: item.signals.bookmarked ? 1 : 0,
      copies: item.signals.memoryMomentCopied ? 1 : 0,
      reflections: item.signals.followupContinued ? 1 : 0,
      surfaces: item.survival.callbackShownCount,
      ignores: 0,
      day7Returns: 0,
      residueScore: item.emotionalResidueScore,
      dead: item.cutCandidate,
    };

    const { decay, reason } = decayMultiplier({
      revisits: metrics.revisits,
      bookmarks: metrics.bookmarks,
      copies: metrics.copies,
      reflections: metrics.reflections,
      surfaces: metrics.surfaces,
      dead: "dead" in metrics ? metrics.dead : item.cutCandidate,
    });

    const earned = earnedScore(metrics, item);
    const net = earned - decay;

    return {
      noteId: item.id,
      text: item.text.slice(0, 100),
      earnedScore: earned,
      decayScore: decay,
      exposureCount: metrics.surfaces,
      earned: net >= EARNED_RESURFACE_THRESHOLD,
      decayReason: reason,
    };
  });

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    rows: rows.sort((a, b) => b.earnedScore - b.decayScore - (a.earnedScore - a.decayScore)),
    earnedCount: rows.filter((r) => r.earned).length,
    decayedCount: rows.filter((r) => !r.earned).length,
  };
}

export function hasEarnedResurfacing(noteId: string, entries?: JournalEntry[]): boolean {
  const report = buildEarnedResurfacingReport(entries);
  return report.rows.find((r) => r.noteId === noteId)?.earned ?? false;
}

export function filterEarnedCandidates<T extends { id: string }>(
  candidates: T[],
  entries?: JournalEntry[],
): T[] {
  const report = buildEarnedResurfacingReport(entries);
  const earned = new Set(report.rows.filter((r) => r.earned).map((r) => r.noteId));
  const filtered = candidates.filter((c) => earned.has(c.id));
  return filtered.length > 0 ? filtered : candidates.slice(0, 1);
}
