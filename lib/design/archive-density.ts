import type { ArchiveExperienceSurfaceKey } from "@/lib/design/archive-page-grammar";

/** Maximum visible cards above the fold per surface. */
export const ARCHIVE_ABOVE_FOLD_CARD_LIMIT: Record<
  ArchiveExperienceSurfaceKey,
  number
> = {
  archive: 4,
  changes: 4,
  reflection_log: 3,
  account: 3,
  archive_detail: 4,
};

export type ArchiveDensityAuditResult = {
  ok: boolean;
  surface: ArchiveExperienceSurfaceKey;
  limit: number;
  estimatedVisibleCards: number;
  violations: string[];
};

/** Heuristic: ArchiveCard + Card with CardHeader in first ~120 lines of main content. */
export function estimateAboveFoldCards(source: string): number {
  const head = source.slice(0, 4500);
  const archiveCards = (head.match(/<ArchiveCard\b/g) ?? []).length;
  const uiCards = (head.match(/<Card\b/g) ?? []).length;
  const healthCards = (head.match(/ArchiveHealthSummary/g) ?? []).length;
  return archiveCards + uiCards + healthCards;
}

export function auditArchiveDensity(
  source: string,
  surface: ArchiveExperienceSurfaceKey,
): ArchiveDensityAuditResult {
  const limit = ARCHIVE_ABOVE_FOLD_CARD_LIMIT[surface];
  const estimatedVisibleCards = estimateAboveFoldCards(source);
  const violations: string[] = [];

  const hasCollapse =
    source.includes("<details") ||
    source.includes("ArchiveDetailsCollapsible") ||
    source.includes("show more") ||
    source.includes("Collapsible");

  if (estimatedVisibleCards > limit && !hasCollapse) {
    violations.push(
      `${surface}: ${estimatedVisibleCards} cards above fold (max ${limit}) — collapse extras`,
    );
  }

  return {
    ok: violations.length === 0,
    surface,
    limit,
    estimatedVisibleCards,
    violations,
  };
}
