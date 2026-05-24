import { buildArchiveGuaranteeReport } from "@/lib/archive/archive-guarantees";
import { buildFutureContinuityReport } from "@/lib/archive/future-continuity";
import { buildArchivePermanenceReviewReport } from "@/lib/debug/archive-permanence-review";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { DurabilityReviewReport, DurabilityReviewRow } from "@/types/emotional-integrity-layer";

function row(
  id: string,
  label: string,
  detail: string,
  category: DurabilityReviewRow["category"],
  severity: DurabilityReviewRow["severity"] = "watch",
): DurabilityReviewRow {
  return { id, label, detail, category, severity };
}

/** Operational durability — sync, migration, lineage, corruption risks. */
export function buildDurabilityReviewReport(): DurabilityReviewReport {
  const entries = getMemoryEligibleEntries();
  const continuity = buildFutureContinuityReport(entries);
  const permanence = buildArchivePermanenceReviewReport(entries);
  const callbacks = buildCallbackQualityReviewReport(entries);
  const dedup = buildCallbackDeduplicationReport(entries);
  const guarantees = buildArchiveGuaranteeReport();

  const rows: DurabilityReviewRow[] = [];

  const failedChecks = continuity.checks.filter((c) => !c.ok);
  const migrationRiskScore = Math.min(
    100,
    failedChecks.length * 18 + (continuity.migrationPreview.callbackIdsStable ? 0 : 25),
  );
  const syncFragilityScore = Math.min(
    100,
    permanence.continuityBreakRisks.length * 15 + guarantees.issues.filter((i) => i.level === "error").length * 20,
  );
  const continuityGapCount = failedChecks.length;

  if (migrationRiskScore >= 40) {
    rows.push(
      row(
        "migration-risk",
        "Migration fragility",
        `${failedChecks.length} continuity check(s) failing`,
        "migration",
        migrationRiskScore >= 60 ? "concern" : "watch",
      ),
    );
  }

  if (syncFragilityScore >= 35) {
    rows.push(
      row(
        "sync-fragility",
        "Sync fragility",
        `${permanence.continuityBreakRisks.length} break risk(s) · ${guarantees.issues.length} guarantee issue(s)`,
        "sync",
        syncFragilityScore >= 55 ? "concern" : "watch",
      ),
    );
  }

  if (continuityGapCount > 0) {
    rows.push(
      row(
        "continuity-gaps",
        "Future continuity gaps",
        `${continuityGapCount} gaps in long-term continuity`,
        "continuity",
        "concern",
      ),
    );
  }

  if (permanence.weakFutureContinuity.length > 0) {
    rows.push(
      row(
        "landmark-drift",
        "Archive continuity drift",
        permanence.weakFutureContinuity.slice(0, 2).join(" · "),
        "dependency",
        "watch",
      ),
    );
  }

  if (dedup.collapsedTemplates.length >= 2) {
    rows.push(
      row(
        "callback-lineage",
        "Callback lineage risk",
        "Repeated structures may corrupt emotional lineage",
        "lineage",
        "watch",
      ),
    );
  }

  const lowLineage = callbacks.items.filter((i) => i.survival.emotionalSurvivalScore < 15);
  if (lowLineage.length >= 3) {
    rows.push(
      row(
        "weak-lineage",
        "Weak callback lineage",
        `${lowLineage.length} callbacks with weak survival scores`,
        "lineage",
        "watch",
      ),
    );
  }

  for (const issue of guarantees.issues.slice(0, 6)) {
    rows.push(
      row(
        `pkg-${issue.message.slice(0, 24)}`,
        "Archive package integrity",
        issue.message,
        "corruption",
        issue.level === "error" ? "concern" : "watch",
      ),
    );
  }

  const emotionalModuleCount = 9;
  rows.push(
    row(
      "maintenance-hotspot",
      "Maintenance hotspot",
      `${emotionalModuleCount} emotional subsystems require ongoing restraint validation`,
      "maintenance",
      "watch",
    ),
  );

  const maintenanceHotspots = rows.filter((r) => r.category === "maintenance").length;
  const continuityRiskScore = Math.min(
    100,
    migrationRiskScore + syncFragilityScore + continuityGapCount * 10 + guarantees.issues.length * 8,
  );

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0 || rows.length > 0,
    rows,
    maintenanceHotspots,
    continuityRiskScore,
  };
}
