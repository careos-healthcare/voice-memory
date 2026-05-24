import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { toDayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { SacrednessInflationWarning, SacrednessReport } from "@/types/sacredness-layer";

function warn(
  kind: SacrednessInflationWarning["kind"],
  label: string,
  detail: string,
  severity: SacrednessInflationWarning["severity"] = "watch",
): SacrednessInflationWarning {
  return { id: `sac-${kind}`, kind, label, detail, severity };
}

/** Detect emotional inflation — oversurfacing, saturation, crowding. */
export function buildSacrednessReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SacrednessReport {
  const callbacks = buildCallbackQualityReviewReport(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const sequencing = buildRevisitSequencingReport();
  const loopOpt = buildLoopOptimizationReport(entries);

  const warnings: SacrednessInflationWarning[] = [];
  const strongCallbacks = callbacks.items.filter((i) => i.emotionalWeight >= 70 || i.doubleDown);
  const bigCallbacks = callbacks.items.filter((i) => i.emotionalWeight >= 75);

  if (silence.sessionNoteCount >= 2 && !silence.weakNoteSuppressed) {
    warnings.push(warn("oversurfacing", "Emotional oversurfacing", `${silence.sessionNoteCount} notes this session`, "concern"));
  }

  if (strongCallbacks.length >= 6) {
    warnings.push(
      warn("too_many_meaningful", "Too many meaningful moments", `${strongCallbacks.length} high-weight callbacks`, "concern"),
    );
  }

  const densityPerEntry =
    entries.length > 0 ? callbacks.items.length / entries.length : 0;
  if (densityPerEntry >= 0.8 && entries.length >= 8) {
    warnings.push(
      warn("density_inflation", "Callback density inflation", `${densityPerEntry.toFixed(1)} callbacks per entry`, "concern"),
    );
  }

  if (sequencing.revisitFatigueActive && sequencing.fatigueScore >= 4) {
    warnings.push(
      warn("saturation", "Emotional saturation", `${sequencing.fatigueScore} revisits in fatigue window`, "concern"),
    );
    warnings.push(
      warn("fatigue", "Emotional fatigue accumulation", `Spacing ${sequencing.recommendedSpacingDays}d`, "watch"),
    );
  }

  const intensitySpread =
    entries.length >= 4
      ? Math.max(...entries.map((e) => e.reflection.emotionalIntensity)) -
        Math.min(...entries.map((e) => e.reflection.emotionalIntensity))
      : 0;
  if (intensitySpread < 2 && entries.length >= 10 && callbacks.items.length >= 5) {
    warnings.push(warn("diminished_contrast", "Diminishing emotional contrast", "Intensity range flattened", "watch"));
  }

  const overexposedBig = loopOpt.topPerforming.filter((r) => r.surfaces >= 4 && r.residueScore >= 55);
  if (bigCallbacks.length >= 3 && overexposedBig.length >= 2) {
    warnings.push(
      warn("big_callback_overuse", "Over-frequent big callbacks", `${overexposedBig.length} heavily surfaced`, "concern"),
    );
  }

  if (warnings.filter((w) => w.severity === "concern").length >= 3) {
    warnings.push(warn("crowding", "Archive emotional crowding", "Multiple inflation signals active", "concern"));
  }

  const concernCount = warnings.filter((w) => w.severity === "concern").length;
  const sacrednessScore = Math.max(0, Math.min(100, 85 - concernCount * 12 - warnings.length * 4));
  const emotionalRarityScore = Math.max(
    0,
    Math.min(100, 100 - strongCallbacks.length * 8 - bigCallbacks.length * 5),
  );
  const silenceValueScore = Math.min(
    100,
    Math.round(
      (silence.weakNoteSuppressed ? 35 : 15) +
        (silence.ignoredCooldownActive ? 25 : 10) +
        (sequencing.revisitFatigueActive ? 20 : 5) +
        (silence.consecutiveIgnored > 0 ? 15 : 0),
    ),
  );

  const emotionallyCrowded = concernCount >= 2 || warnings.some((w) => w.kind === "crowding");
  const meaningfulnessInflated = warnings.some((w) => w.kind === "too_many_meaningful" || w.kind === "density_inflation");
  const silencePreferred = silenceValueScore >= 55 && (sequencing.revisitFatigueActive || silence.ignoredCooldownActive);

  const founderWarnings: string[] = [];
  if (emotionallyCrowded) founderWarnings.push("The archive may be becoming emotionally crowded.");
  if (meaningfulnessInflated) founderWarnings.push("Too many moments are being treated as meaningful.");
  if (silencePreferred) founderWarnings.push("Silence may now be more valuable than resurfacing.");

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0 || callbacks.hasData,
    sacrednessScore,
    emotionalRarityScore,
    silenceValueScore,
    inflationWarnings: warnings,
    emotionallyCrowded,
    meaningfulnessInflated,
    silencePreferred,
    founderWarnings,
  };
}

export function weeklyDensityTrend(entries: JournalEntry[]): Array<{ period: string; density: number; resurfacingCount: number }> {
  const callbacks = buildCallbackQualityReviewReport(entries);
  const entryWeek = new Map(entries.map((e) => [e.id, toDayKey(e.createdAt).slice(0, 7)]));
  const byWeek = new Map<string, { entries: number; callbacks: number }>();

  for (const entry of entries) {
    const week = toDayKey(entry.createdAt).slice(0, 7);
    const row = byWeek.get(week) ?? { entries: 0, callbacks: 0 };
    row.entries += 1;
    byWeek.set(week, row);
  }

  for (const item of callbacks.items) {
    const entryId = item.sourceEntries[0]?.id;
    const week = entryId ? entryWeek.get(entryId) : undefined;
    if (!week) continue;
    const row = byWeek.get(week) ?? { entries: 0, callbacks: 0 };
    row.callbacks += 1;
    byWeek.set(week, row);
  }

  return [...byWeek.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-8)
    .map(([period, row]) => ({
      period,
      density: row.entries > 0 ? Math.round((row.callbacks / row.entries) * 10) / 10 : 0,
      resurfacingCount: row.callbacks,
    }));
}
