import { buildSurfaceAuditReport } from "@/lib/product/surface-audit";
import { ARCHIVE_PRODUCT_ONE_LINER } from "@/lib/product/archive-product-questions";

export const SIMPLIFICATION_TARGET_CONCEPTS = [
  "Archive",
  "Evidence",
  "Changes",
  "Reflections",
] as const;

export const LEGACY_VISIBLE_CONCEPTS = [
  "Archive",
  "Journal",
  "Memory",
  "Insights",
  "Theories",
  "Blind Spots",
  "Discover",
  "Updates",
  "Timeline",
  "Search",
  "Patterns",
  "Weekly",
  "Bookmarks",
] as const;

export interface ProductSimplificationReport {
  generatedAt: string;
  currentConceptCount: number;
  targetConceptCount: number;
  simplificationScore: number;
  oneLiner: string;
  meetsTarget: boolean;
  conceptRows: Array<{ concept: string; status: "primary" | "renamed" | "utility" | "hidden" }>;
  auditLines: string[];
  recommendation: string;
}

export function buildProductSimplificationReport(): ProductSimplificationReport {
  const audit = buildSurfaceAuditReport();
  const currentConceptCount = LEGACY_VISIBLE_CONCEPTS.length;
  const targetConceptCount = SIMPLIFICATION_TARGET_CONCEPTS.length;
  const simplificationScore = Math.round(
    (targetConceptCount / currentConceptCount) * 100,
  );
  const meetsTarget = currentConceptCount <= targetConceptCount + 1;

  const conceptRows: ProductSimplificationReport["conceptRows"] = [
    { concept: "Archive", status: "primary" },
    { concept: "Evidence", status: "primary" },
    { concept: "Changes", status: "renamed" },
    { concept: "Reflections", status: "renamed" },
    { concept: "Discover", status: "primary" },
    { concept: "Blind Spots", status: "renamed" },
    { concept: "Theories", status: "renamed" },
    { concept: "Memory", status: "renamed" },
    { concept: "Journal", status: "hidden" },
    { concept: "Insights", status: "hidden" },
    { concept: "Updates", status: "renamed" },
    { concept: "Timeline", status: "utility" },
    { concept: "Search", status: "utility" },
  ];

  return {
    generatedAt: new Date().toISOString(),
    currentConceptCount,
    targetConceptCount,
    simplificationScore,
    oneLiner: ARCHIVE_PRODUCT_ONE_LINER,
    meetsTarget: false,
    conceptRows,
    auditLines: audit.lines,
    recommendation:
      simplificationScore >= 30
        ? "Navigation and archive command center align with four-concept target; keep engines, hide labels behind Account > More."
        : "Continue demoting utility surfaces; archive-belief must remain the returning home.",
  };
}
