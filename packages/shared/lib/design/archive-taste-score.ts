export const ARCHIVE_TASTE_TARGET = 90;

export type ArchiveTasteSubscores = {
  copyDensity: number;
  animationDensity: number;
  emptyStateQuality: number;
  ctaCompetition: number;
  spacingConsistency: number;
};

export type ArchiveTasteScore = ArchiveTasteSubscores & {
  total: number;
  target: number;
  passesTarget: boolean;
};

export function scoreFromRatio(passed: number, total: number): number {
  if (total <= 0) return 100;
  return Math.round((passed / total) * 100);
}

export function buildArchiveTasteScore(checks: {
  copyDensity: { passed: number; total: number };
  animationDensity: { passed: number; total: number };
  emptyStateQuality: { passed: number; total: number };
  ctaCompetition: { passed: number; total: number };
  spacingConsistency: { passed: number; total: number };
}): ArchiveTasteScore {
  const copyDensity = scoreFromRatio(
    checks.copyDensity.passed,
    checks.copyDensity.total,
  );
  const animationDensity = scoreFromRatio(
    checks.animationDensity.passed,
    checks.animationDensity.total,
  );
  const emptyStateQuality = scoreFromRatio(
    checks.emptyStateQuality.passed,
    checks.emptyStateQuality.total,
  );
  const ctaCompetition = scoreFromRatio(
    checks.ctaCompetition.passed,
    checks.ctaCompetition.total,
  );
  const spacingConsistency = scoreFromRatio(
    checks.spacingConsistency.passed,
    checks.spacingConsistency.total,
  );

  const total = Math.round(
    (copyDensity +
      animationDensity +
      emptyStateQuality +
      ctaCompetition +
      spacingConsistency) /
      5,
  );

  return {
    copyDensity,
    animationDensity,
    emptyStateQuality,
    ctaCompetition,
    spacingConsistency,
    total,
    target: ARCHIVE_TASTE_TARGET,
    passesTarget: total >= ARCHIVE_TASTE_TARGET,
  };
}
