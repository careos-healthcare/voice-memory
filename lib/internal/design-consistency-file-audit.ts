import fs from "node:fs";
import path from "node:path";

import { auditArchiveCtas } from "@/lib/design/archive-cta-map";
import { auditArchiveDensity } from "@/lib/design/archive-density";
import {
  ARCHIVE_SURFACE_GRAMMAR,
  assertGrammarSectionOrder,
  extractGrammarSectionsFromSource,
  grammarSectionsFromBlueprintSource,
  type ArchiveExperienceSurfaceKey,
} from "@/lib/design/archive-page-grammar";
import { auditArchiveSpacing } from "@/lib/design/archive-spacing-audit";
import { auditArchiveTypography } from "@/lib/design/archive-typography-audit";
import {
  buildDesignConsistencyScore,
  type DesignConsistencyScore,
  type SurfaceScanAudit,
} from "@/lib/design/design-consistency-score";
import {
  MOBILE_ARCHIVE_SURFACES,
  auditMobileParity,
} from "@/lib/design/mobile-design-consistency-audit";
import { auditAllSurfaceScanPatterns } from "@/lib/design/scan-pattern-audit";
import { auditVisualWeightFromSource } from "@/lib/design/archive-visual-weight";

const ROOT = process.cwd();

function read(rel: string): string {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const BLUEPRINT_SOURCE = "components/layout/ArchivePageBlueprint.tsx";

function readSurfaceSources(spec: { sourceFiles: string[] }): string {
  return [BLUEPRINT_SOURCE, ...spec.sourceFiles].map((f) => read(f)).join("\n");
}

export type DesignConsistencyFileReport = {
  score: DesignConsistencyScore;
  scanPatterns: SurfaceScanAudit[];
  failures: string[];
  notes: string[];
};

export function buildDesignConsistencyFileReport(): DesignConsistencyFileReport {
  const failures: string[] = [];
  const notes: string[] = [];

  let typoPass = 0;
  let typoTotal = 0;
  let spacePass = 0;
  let spaceTotal = 0;
  let hierarchyPass = 0;
  let hierarchyTotal = 0;
  let ctaPass = 0;
  let ctaTotal = 0;
  let weightPass = 0;
  let weightTotal = 0;
  let mobilePass = 0;
  let mobileTotal = 0;

  const surfaceSources: Record<ArchiveExperienceSurfaceKey, string> = {
    archive: "",
    changes: "",
    reflection_log: "",
    account: "",
    archive_detail: "",
  };

  for (const spec of ARCHIVE_SURFACE_GRAMMAR) {
    const src = readSurfaceSources(spec);
    surfaceSources[spec.surface] = src;

    typoTotal += 1;
    const typo = auditArchiveTypography(src, spec.surface);
    if (typo.ok) typoPass += 1;
    else failures.push(...typo.violations);

    spaceTotal += 1;
    const space = auditArchiveSpacing(src, spec.surface);
    if (space.ok) spacePass += 1;
    else failures.push(...space.violations);

    hierarchyTotal += 1;
    const grammar = [
      ...extractGrammarSectionsFromSource(src),
      ...grammarSectionsFromBlueprintSource(src),
    ];
    const orderOk =
      grammar.length === 0
        ? src.includes("ArchivePageBlueprint")
        : assertGrammarSectionOrder(grammar);
    if (orderOk && src.includes("ArchivePageBlueprint")) hierarchyPass += 1;
    else {
      failures.push(`${spec.surface}: grammar/blueprint section order invalid`);
    }

    ctaTotal += 1;
    const cta = auditArchiveCtas(src, spec.surface);
    if (cta.ok) ctaPass += 1;
    else failures.push(...cta.violations);

    weightTotal += 1;
    const weight = auditVisualWeightFromSource(src, spec.surface);
    if (weight.ok) weightPass += 1;
    else failures.push(...weight.violations);

    const density = auditArchiveDensity(src, spec.surface);
    if (!density.ok) failures.push(...density.violations);

    if (!src.includes("ArchivePageBlueprint") && spec.surface !== "archive_detail") {
      failures.push(`${spec.surface}: must use ArchivePageBlueprint`);
    }
  }

  const scanPatterns = auditAllSurfaceScanPatterns(surfaceSources);
  for (const scan of scanPatterns) {
    if (scan.verdict === "INCONSISTENT") {
      failures.push(`${scan.surface}: scan pattern ${scan.notes.join("; ")}`);
    }
  }

  for (const mobile of MOBILE_ARCHIVE_SURFACES) {
    mobileTotal += 1;
    const web = surfaceSources[mobile.surface];
    const webGrammar = [
      ...extractGrammarSectionsFromSource(web),
      ...grammarSectionsFromBlueprintSource(web),
    ];
    const dart = mobile.dartFiles.map((f) => read(f)).join("\n");
    const parity = auditMobileParity(webGrammar, dart, mobile.surface);
    if (parity.ok) mobilePass += 1;
    else failures.push(...parity.violations);
  }

  const score = buildDesignConsistencyScore({
    typography: { passed: typoPass, total: typoTotal },
    spacing: { passed: spacePass, total: spaceTotal },
    hierarchy: { passed: hierarchyPass, total: hierarchyTotal },
    cta: { passed: ctaPass, total: ctaTotal },
    visualWeight: { passed: weightPass, total: weightTotal },
    mobile: { passed: mobilePass, total: mobileTotal },
  });

  if (!score.passesTarget) {
    notes.push(`Design consistency ${score.total} below target ${score.target}`);
  }

  return { score, scanPatterns, failures, notes };
}
