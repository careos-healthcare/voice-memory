import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { revisitedEntryCount } from "@/lib/callback-interaction-signals";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { ArchiveDepthReport, ArchiveDensitySignals } from "@/types/memory-compounding";

function collectLoopMetrics(report: ReturnType<typeof buildLoopOptimizationReport>) {
  const merged = [
    ...report.topPerforming,
    ...report.causingRevisits,
    ...report.causingReflections,
    ...report.topCopied,
  ];
  const seen = new Set<string>();
  return merged.filter((row) => {
    if (seen.has(row.noteId)) return false;
    seen.add(row.noteId);
    return true;
  });
}

const DENSITY_HISTORY_KEY = "voicememory_archive_density_history";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readDensityHistory(): Array<{ period: string; score: number }> {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(DENSITY_HISTORY_KEY);
    const parsed = raw ? (JSON.parse(raw) as Array<{ period: string; score: number }>) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function appendDensitySnapshot(score: number): Array<{ period: string; score: number }> {
  const period = todayKey().slice(0, 7);
  const history = readDensityHistory().filter((row) => row.period !== period);
  history.push({ period, score });
  const trimmed = history.slice(-12);
  if (isBrowser()) {
    localStorage.setItem(DENSITY_HISTORY_KEY, JSON.stringify(trimmed));
  }
  return trimmed;
}

function computeSignals(entries: JournalEntry[]): ArchiveDensitySignals {
  const loops = buildRetentionLoopReport();
  const remembered = buildRememberedLaterReport(entries);
  const revisited = revisitedEntryCount();

  const revisitEvents = loops.events.filter(
    (e) => e.kind === "entry_revisited" || e.kind === "old_entry_opened_from_note",
  );
  const uniqueRevisited = new Set(revisitEvents.map((e) => e.entryId ?? e.targetEntryId).filter(Boolean));
  const oldEntryReuseRate =
    entries.length > 0 ? Math.min(100, Math.round((uniqueRevisited.size / entries.length) * 100)) : 0;

  const quoteResurfacing = loops.notesCausingRevisits.filter((n) => n.clicks > 0 || n.oldEntryOpens > 0);
  const quoteResurfacingRate =
    loops.notesCausingRevisits.length > 0
      ? Math.round((quoteResurfacing.length / loops.notesCausingRevisits.length) * 100)
      : 0;

  const revisitDepthScore = Math.min(
    100,
    revisitEvents.length * 4 + loops.revisitsCausingReflections.length * 12,
  );

  const callbackReport = buildCallbackQualityReviewReport(entries);
  const surviving = callbackReport.items.filter((i) => i.survival.emotionalSurvivalScore >= 35);
  const continuitySurvivalScore =
    callbackReport.items.length > 0
      ? Math.round((surviving.length / callbackReport.items.length) * 100)
      : 0;

  const delayedRevisitReflectionRate =
    loops.revisitsCausingReflections.length > 0
      ? Math.min(100, loops.revisitsCausingReflections.length * 15)
      : 0;

  const copiedReopenedWeeksLaterRate = Math.min(
    100,
    remembered.copiedReopenedCount * 20 + remembered.remembered72hCount * 8,
  );

  return {
    oldEntryReuseRate,
    quoteResurfacingRate,
    revisitDepthScore,
    continuitySurvivalScore,
    delayedRevisitReflectionRate,
    copiedReopenedWeeksLaterRate,
  };
}

function densityScoreFromSignals(signals: ArchiveDensitySignals): number {
  return Math.round(
    signals.oldEntryReuseRate * 0.18 +
      signals.quoteResurfacingRate * 0.14 +
      signals.revisitDepthScore * 0.2 +
      signals.continuitySurvivalScore * 0.22 +
      signals.delayedRevisitReflectionRate * 0.14 +
      signals.copiedReopenedWeeksLaterRate * 0.12,
  );
}

function densityTrend(
  history: Array<{ period: string; score: number }>,
  current: number,
): "rising" | "flat" | "weak" {
  if (current < 28) return "weak";
  if (history.length < 2) return "flat";
  const prev = history[history.length - 2]?.score ?? current;
  if (current >= prev + 5) return "rising";
  if (current <= prev - 8) return "weak";
  return "flat";
}

/** Internal archive meaning density observation — debug only. */
export function buildArchiveDepthReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveDepthReport {
  const signals = computeSignals(entries);
  const densityScore = densityScoreFromSignals(signals);
  const densityHistory = appendDensitySnapshot(densityScore);

  const loopReport = buildLoopOptimizationReport(entries);
  const callbackReport = buildCallbackQualityReviewReport(entries);

  const weakArchiveZones: ArchiveDepthReport["weakArchiveZones"] = [];
  if (signals.oldEntryReuseRate < 15 && entries.length >= 8) {
    weakArchiveZones.push({
      id: "reuse-low",
      label: "Old entries rarely reopened",
      reason: `Reuse rate ${signals.oldEntryReuseRate}%`,
    });
  }
  if (signals.continuitySurvivalScore < 30) {
    weakArchiveZones.push({
      id: "continuity-weak",
      label: "Callbacks fading quickly",
      reason: `Survival ${signals.continuitySurvivalScore}%`,
    });
  }
  if (signals.delayedRevisitReflectionRate < 10) {
    weakArchiveZones.push({
      id: "delayed-reflection",
      label: "Few revisit → reflection chains",
      reason: "Long-horizon payoff not compounding yet",
    });
  }

  const strongestLongitudinalCallbacks = [
    ...callbackReport.items
      .filter((i) => i.emotionalResidueScore >= 50)
      .map((i) => ({ id: i.id, text: i.text, score: i.emotionalResidueScore })),
    ...collectLoopMetrics(loopReport)
      .filter((r) => !r.dead && r.residueScore >= 45)
      .map((r) => ({ id: r.noteId, text: r.noteText, score: r.residueScore })),
  ]
    .sort((a, b) => b.score - a.score)
    .slice(0, 12);

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length >= 4,
    densityScore,
    densityTrend: densityTrend(densityHistory, densityScore),
    signals,
    weakArchiveZones,
    strongestLongitudinalCallbacks,
    densityHistory,
  };
}
