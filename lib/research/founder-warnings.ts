import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { LAUNCH_EVENTS, countLocalEvents, readLocalEvents } from "@/lib/local-analytics";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import { readWeeklyRetentionSnapshots } from "@/lib/validation/observation-summaries";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FounderWarning, FounderWarningsReport } from "@/types/validation-ops";

function warning(
  kind: FounderWarning["kind"],
  label: string,
  detail: string,
  severity: FounderWarning["severity"] = "watch",
): FounderWarning {
  return { id: `warn-${kind}`, kind, label, detail, severity };
}

/** Founder warnings — calm observation, not growth dashboard alerts. */
export function buildFounderWarningsReport(): FounderWarningsReport {
  const entries = getMemoryEligibleEntries();
  const loops = buildRetentionLoopReport();
  const sequencing = buildRevisitSequencingReport();
  const loopOpt = buildLoopOptimizationReport(entries);
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const sharing = buildShareObservationReport();
  const weekly = readWeeklyRetentionSnapshots();
  const warnings: FounderWarning[] = [];

  const heavyReopen = loops.notesCausingRevisits.filter((n) => n.oldEntryOpens >= 4);
  if (heavyReopen.length >= 2) {
    warnings.push(
      warning(
        "callback_repetition",
        "Callbacks becoming repetitive",
        `${heavyReopen.length} callbacks reopened heavily`,
        "concern",
      ),
    );
  }

  const deadWithReopens = loopOpt.deadCallbacks.filter((row) => row.revisits > 0);
  if (deadWithReopens.length >= 2) {
    warnings.push(
      warning(
        "callback_repetition",
        "Dead callbacks still resurfacing",
        `${deadWithReopens.length} low-payoff callbacks getting revisits`,
      ),
    );
  }

  if (sequencing.revisitFatigueActive) {
    warnings.push(
      warning(
        "revisit_fatigue",
        "Revisit fatigue rising",
        `${sequencing.fatigueScore} revisits in 7 days · spacing ${sequencing.recommendedSpacingDays}d`,
        "concern",
      ),
    );
  }

  if (legitimacy.scores.overclaimRisk >= 50) {
    warnings.push(
      warning(
        "emotional_overclaim",
        "Emotional overclaim risk increasing",
        `Overclaim risk ${legitimacy.scores.overclaimRisk} · genericity ${legitimacy.scores.genericityRisk}`,
        "concern",
      ),
    );
  }

  if (weekly.length >= 2) {
    const recent = weekly[weekly.length - 1];
    const prior = weekly[weekly.length - 2];
    if (
      prior.day7Returns > 0 &&
      recent.day7Returns < prior.day7Returns &&
      recent.returnDayCount <= prior.returnDayCount
    ) {
      warnings.push(
        warning(
          "retention_novelty_drop",
          "Retention dropped after novelty",
          `D7 returns ${prior.day7Returns} → ${recent.day7Returns}`,
          "concern",
        ),
      );
    }
  }

  const shareCount =
    sharing.sharedCallbacksCount + sharing.sharedRevisitMomentsCount;

  if (shareCount >= 3 && sharing.revisitAfterShareCount === 0) {
    warnings.push(
      warning(
        "performative_sharing",
        "Sharing may be performative",
        `${shareCount} shares with no revisit-after-share`,
      ),
    );
  }

  const exportCount = countLocalEvents(LAUNCH_EVENTS.exportUsed);
  const recentActivity = readLocalEvents().filter((e) => {
    const days = (Date.now() - new Date(e.at).getTime()) / 86400000;
    return days <= 14;
  }).length;

  if (exportCount >= 2 && recentActivity <= 2 && entries.length >= 6) {
    warnings.push(
      warning(
        "export_before_churn",
        "Archive exports rising before quiet period",
        `${exportCount} exports · only ${recentActivity} events in last 14 days`,
        "concern",
      ),
    );
  }

  return {
    generatedAt: new Date().toISOString(),
    warnings,
  };
}
