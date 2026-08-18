import type { ArchiveExperienceSurfaceKey } from "@/lib/design/archive-page-grammar";

export type DesignConsistencySubscores = {
  typography: number;
  spacing: number;
  hierarchy: number;
  cta: number;
  visualWeight: number;
  mobile: number;
};

export type DesignConsistencyScore = DesignConsistencySubscores & {
  total: number;
  target: number;
  passesTarget: boolean;
};

export const DESIGN_CONSISTENCY_TARGET = 95;

export function scoreFromRatio(passed: number, total: number): number {
  if (total <= 0) return 100;
  return Math.round((passed / total) * 100);
}

export function buildDesignConsistencyScore(
  checks: {
    typography: { passed: number; total: number };
    spacing: { passed: number; total: number };
    hierarchy: { passed: number; total: number };
    cta: { passed: number; total: number };
    visualWeight: { passed: number; total: number };
    mobile: { passed: number; total: number };
  },
): DesignConsistencyScore {
  const typography = scoreFromRatio(checks.typography.passed, checks.typography.total);
  const spacing = scoreFromRatio(checks.spacing.passed, checks.spacing.total);
  const hierarchy = scoreFromRatio(checks.hierarchy.passed, checks.hierarchy.total);
  const cta = scoreFromRatio(checks.cta.passed, checks.cta.total);
  const visualWeight = scoreFromRatio(checks.visualWeight.passed, checks.visualWeight.total);
  const mobile = scoreFromRatio(checks.mobile.passed, checks.mobile.total);

  const total = Math.round(
    (typography + spacing + hierarchy + cta + visualWeight + mobile) / 6,
  );

  return {
    typography,
    spacing,
    hierarchy,
    cta,
    visualWeight,
    mobile,
    total,
    target: DESIGN_CONSISTENCY_TARGET,
    passesTarget: total >= DESIGN_CONSISTENCY_TARGET,
  };
}

export type SurfaceScanVerdict = "CONSISTENT" | "INCONSISTENT";

export type SurfaceScanAudit = {
  surface: ArchiveExperienceSurfaceKey;
  verdict: SurfaceScanVerdict;
  firstVisible: string;
  largestHeading: string;
  primaryCta: string | null;
  sectionOrder: string[];
  notes: string[];
};
