import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import { buildPilotInterestReport } from "@/lib/pilot/pilot-interest";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { RemovalReviewReport, RemovalReviewRow } from "@/types/emotional-integrity-layer";

function row(
  id: string,
  label: string,
  detail: string,
  rank: RemovalReviewRow["rank"],
  score: number,
): RemovalReviewRow {
  return { id, label, detail, rank, score };
}

/** Detect dead systems, low-trust surfaces, and emotionally dilutive features. */
export function buildRemovalReviewReport(): RemovalReviewReport {
  const entries = getMemoryEligibleEntries();
  const callbacks = buildCallbackQualityReviewReport(entries);
  const loop = buildLoopOptimizationReport(entries);
  const sharing = buildShareObservationReport();
  const monetization = buildMonetizationObservationReport();
  const pilot = buildPilotInterestReport();

  const rows: RemovalReviewRow[] = [];

  for (const dead of loop.deadCallbacks.slice(0, 8)) {
    rows.push(
      row(
        `dead-${dead.noteId}`,
        "Dead callback",
        dead.noteText.slice(0, 80),
        "safe_to_remove",
        85,
      ),
    );
  }

  for (const item of callbacks.items.filter((i) => i.cutCandidate).slice(0, 6)) {
    rows.push(
      row(
        `cut-${item.id}`,
        "Cut candidate callback",
        item.text.slice(0, 80),
        "safe_to_remove",
        75,
      ),
    );
  }

  if (sharing.inviteOpensCount > 0 && sharing.sharedCallbacksCount === 0) {
    rows.push(
      row(
        "share-prompts-unused",
        "Share prompts without uptake",
        "Prompts may add noise without attachment",
        "emotionally_dilutive",
        60,
      ),
    );
  }

  if (monetization.premiumLinesSeen > 0 && monetization.trustDropAfterPremium > 0) {
    rows.push(
      row(
        "premium-trust-drop",
        "Premium surface trust drop",
        "Monetization copy may be diluting trust",
        "risky_to_keep",
        70,
      ),
    );
  }

  if (pilot.summary.pageViews > 0 && pilot.summary.trustDrops > 0) {
    rows.push(
      row(
        "pilot-trust-drop",
        "Pilot surface trust drop",
        `${pilot.summary.trustDrops} trust drop(s) after pilot exposure`,
        "risky_to_keep",
        55,
      ),
    );
  }

  const lowSurvival = callbacks.items.filter((i) => i.survival.emotionalSurvivalScore < 18);
  if (lowSurvival.length >= 4) {
    rows.push(
      row(
        "low-survival-batch",
        "Low-survival callback batch",
        `${lowSurvival.length} callbacks below survival threshold`,
        "emotionally_dilutive",
        65,
      ),
    );
  }

  const noveltyOnly = callbacks.items.filter(
    (i) =>
      i.rewriteFlags.includes("could_apply_to_many") &&
      !i.manualLabels.includes("emotionally_precise") &&
      !i.manualLabels.includes("landed_emotionally"),
  );
  for (const item of noveltyOnly.slice(0, 4)) {
    rows.push(
      row(
        `novelty-${item.id}`,
        "Novelty-only callback",
        item.text.slice(0, 80),
        "emotionally_dilutive",
        50,
      ),
    );
  }

  rows.sort((a, b) => b.score - a.score);

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0 || callbacks.hasData,
    rows,
    safeToRemove: rows.filter((r) => r.rank === "safe_to_remove"),
    riskyToKeep: rows.filter((r) => r.rank === "risky_to_keep"),
    emotionallyDilutive: rows.filter((r) => r.rank === "emotionally_dilutive"),
  };
}
