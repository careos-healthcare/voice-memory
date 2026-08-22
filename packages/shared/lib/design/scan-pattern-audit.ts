import {
  ARCHIVE_SURFACE_GRAMMAR,
  assertGrammarSectionOrder,
  extractGrammarSectionsFromSource,
  grammarSectionsFromBlueprintSource,
  type ArchiveExperienceSurfaceKey,
} from "@/lib/design/archive-page-grammar";
import type { SurfaceScanAudit, SurfaceScanVerdict } from "@/lib/design/design-consistency-score";

export function auditSurfaceScanPattern(
  surface: ArchiveExperienceSurfaceKey,
  combinedSource: string,
): SurfaceScanAudit {
  const spec = ARCHIVE_SURFACE_GRAMMAR.find((s) => s.surface === surface);
  const grammar = extractGrammarSectionsFromSource(combinedSource);
  const blueprintGrammar = grammarSectionsFromBlueprintSource(combinedSource);
  const sectionOrder = grammar.length ? grammar : blueprintGrammar;

  const notes: string[] = [];
  let verdict: SurfaceScanVerdict = "CONSISTENT";

  if (!assertGrammarSectionOrder(sectionOrder)) {
    verdict = "INCONSISTENT";
    notes.push("Section order violates PAGE_STRUCTURE");
  }

  const usesBlueprint = combinedSource.includes("ArchivePageBlueprint");
  const effectiveOrder =
    sectionOrder.length > 0
      ? sectionOrder
      : usesBlueprint && spec
        ? spec.requiredSections
        : [];

  if (spec && usesBlueprint) {
    for (const required of spec.requiredSections) {
      if (!effectiveOrder.includes(required)) {
        notes.push(`Missing grammar section: ${required}`);
        verdict = "INCONSISTENT";
      }
    }
  }

  const firstGrammar = sectionOrder[0] ?? spec?.firstVisible ?? "unknown";
  const hasPageTitle =
    combinedSource.includes("ARCHIVE_TYPO.pageTitle") ||
    combinedSource.includes("PageTitle") ||
    combinedSource.includes('archiveTypo("pageTitle")');

  if (!hasPageTitle && spec?.largestHeadingRole === "PageTitle" && usesBlueprint) {
    notes.push("Largest heading should use PageTitle role");
    verdict = "INCONSISTENT";
  }

  const primaryCta =
    spec?.primaryCtaLabel && combinedSource.includes(spec.primaryCtaLabel)
      ? spec.primaryCtaLabel
      : combinedSource.includes("ArchiveActionArea")
        ? "ArchiveActionArea"
        : null;

  if (
    spec?.primaryCtaLabel &&
    !combinedSource.includes(spec.primaryCtaLabel) &&
    !combinedSource.includes("ArchiveActionArea")
  ) {
    notes.push("Primary CTA not found");
    verdict = "INCONSISTENT";
  }

  if (usesBlueprint && assertGrammarSectionOrder(effectiveOrder)) {
    verdict = notes.length ? verdict : "CONSISTENT";
  }

  return {
    surface,
    verdict,
    firstVisible: String(effectiveOrder[0] ?? spec?.firstVisible ?? firstGrammar),
    largestHeading: spec?.largestHeadingRole ?? "PageTitle",
    primaryCta,
    sectionOrder: effectiveOrder,
    notes,
  };
}

export function auditAllSurfaceScanPatterns(
  sources: Record<ArchiveExperienceSurfaceKey, string>,
): SurfaceScanAudit[] {
  return (Object.keys(sources) as ArchiveExperienceSurfaceKey[]).map((surface) =>
    auditSurfaceScanPattern(surface, sources[surface] ?? ""),
  );
}
