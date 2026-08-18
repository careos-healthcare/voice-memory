import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildSuppressionReviewReport } from "@/lib/debug/suppression-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveSimplicityReport, ArchiveSimplicityRow } from "@/types/emotional-integrity-layer";

const EMOTIONAL_MODULES = [
  { id: "refinement", label: "Refinement / callbacks", paths: ["lib/refinement/"] },
  { id: "memory", label: "Memory surfacing", paths: ["lib/memory/"] },
  { id: "archive", label: "Archive permanence", paths: ["lib/archive/"] },
  { id: "social-proof", label: "Social proof", paths: ["lib/social-proof/"] },
  { id: "sharing", label: "Quiet sharing", paths: ["lib/sharing/"] },
  { id: "monetization", label: "Monetization", paths: ["lib/monetization/"] },
  { id: "pilot", label: "Pilot", paths: ["lib/pilot/"] },
  { id: "validation", label: "Validation ops", paths: ["lib/validation/", "lib/research/"] },
  { id: "integrity", label: "Integrity layer", paths: ["lib/integrity/"] },
];

const DETECTOR_OVERLAPS: Array<{ id: string; label: string; detail: string }> = [
  {
    id: "overclaim-detectors",
    label: "Overclaim detectors overlap",
    detail: "emotional-proof, emotional-integrity, testimonial-review, callback-quality",
  },
  {
    id: "suppression-detectors",
    label: "Suppression detectors overlap",
    detail: "suppression-review, silence-calibration, revisit-sequencing, emotional-integrity",
  },
  {
    id: "callback-quality-detectors",
    label: "Callback quality overlap",
    detail: "callback-quality-review, callback-deduplication, permanent-callbacks",
  },
  {
    id: "founder-review-detectors",
    label: "Founder review overlap",
    detail: "founder-review, emotional-legitimacy, emotional-integrity, validation-ops",
  },
];

function row(
  id: string,
  label: string,
  detail: string,
  category: ArchiveSimplicityRow["category"],
): ArchiveSimplicityRow {
  return { id, label, detail, category };
}

/** Archive simplicity review — what could be removed without hurting attachment? */
export function buildArchiveSimplicityReport(): ArchiveSimplicityReport {
  const entries = getMemoryEligibleEntries();
  const callbacks = buildCallbackQualityReviewReport(entries);
  const dedup = buildCallbackDeduplicationReport(entries);
  const sequencing = buildRevisitSequencingReport();
  const suppression = buildSuppressionReviewReport(entries);

  const rows: ArchiveSimplicityRow[] = [];

  for (const overlap of DETECTOR_OVERLAPS) {
    rows.push(row(overlap.id, overlap.label, overlap.detail, "overlap"));
  }

  for (const mod of EMOTIONAL_MODULES) {
    rows.push(
      row(
        `module-${mod.id}`,
        mod.label,
        `Surface area: ${mod.paths.join(", ")}`,
        "hotspot",
      ),
    );
  }

  if (dedup.collapsedTemplates.length > 0) {
    rows.push(
      row(
        "callback-template-collapse",
        "Callback template collapse",
        dedup.collapsedTemplates.join("; "),
        "duplicate",
      ),
    );
  }

  if (sequencing.suppressedAdjacentCount > 0 && sequencing.revisitFatigueActive) {
    rows.push(
      row(
        "resurfacing-redundancy",
        "Resurfacing redundancy",
        "Adjacent suppression + fatigue both active — consider consolidating",
        "redundant_surface",
      ),
    );
  }

  const suppressionRate =
    suppression.totalCandidates > 0 ? suppression.suppressedCount / suppression.totalCandidates : 0;
  if (suppressionRate > 0.65 && suppression.totalCandidates >= 8) {
    rows.push(
      row(
        "heavy-suppression",
        "Heavy suppression overlap",
        `${Math.round(suppressionRate * 100)}% of candidates suppressed across modules`,
        "unused",
      ),
    );
  }

  if (callbacks.items.filter((i) => i.cutCandidate).length >= 5) {
    rows.push(
      row(
        "cut-candidates",
        "Many cut candidates",
        `${callbacks.items.filter((i) => i.cutCandidate).length} callbacks flagged for removal`,
        "redundant_surface",
      ),
    );
  }

  const overlapScore = Math.min(
    100,
    DETECTOR_OVERLAPS.length * 12 +
      dedup.collapsedTemplates.length * 10 +
      (suppressionRate > 0.65 ? 15 : 0),
  );

  const overdesigned = overlapScore >= 55 || DETECTOR_OVERLAPS.length >= 3;

  return {
    generatedAt: new Date().toISOString(),
    hasData: callbacks.hasData || rows.length > 0,
    rows,
    removalQuestion: "What could be removed without hurting attachment?",
    overlapScore,
    overdesigned,
  };
}
