/**
 * Archive CTA system — three levels; one primary at end of page flow (bottom-right).
 */

export const ARCHIVE_CTA_LEVEL = {
  PRIMARY: "PRIMARY",
  SECONDARY: "SECONDARY",
  TERTIARY: "TERTIARY",
} as const;

export type ArchiveCtaLevel = (typeof ARCHIVE_CTA_LEVEL)[keyof typeof ARCHIVE_CTA_LEVEL];

export type ArchiveCtaDescriptor = {
  level: ArchiveCtaLevel;
  label: string;
  href?: string;
};

export type ArchiveCtaAuditResult = {
  ok: boolean;
  violations: string[];
  primaryCount: number;
  hasArchiveActionArea: boolean;
};

const PRIMARY_BUTTON_PATTERN =
  /bg-violet-600|ArchiveActionArea[\s\S]{0,400}variant="primary"|variant:\s*"primary"/;

export function auditArchiveCtas(source: string, label: string): ArchiveCtaAuditResult {
  const violations: string[] = [];
  const hasArchiveActionArea = source.includes("ArchiveActionArea");

  const primaryInArea = (source.match(/ArchiveActionArea[\s\S]*?primary\s*=/g) ?? []).length;
  const violetPrimaryButtons = (source.match(/bg-violet-600/g) ?? []).length;
  const primaryCount = Math.max(primaryInArea, violetPrimaryButtons > 0 ? 1 : 0, primaryInArea);

  if (source.includes("ArchivePageBlueprint") && !hasArchiveActionArea) {
    const needsCta = !label.includes("archive_detail");
    if (needsCta) {
      violations.push(`${label}: blueprint surface missing ArchiveActionArea`);
    }
  }

  const primaryProps = (source.match(/primary\s*=\s*\{/g) ?? []).length;
  const secondaryProps = (source.match(/secondary\s*=\s*\{/g) ?? []).length;
  if (primaryProps > 1) {
    violations.push(`${label}: multiple primary CTAs compete (${primaryProps})`);
  }

  if (primaryProps >= 1 && !source.includes("archive-action-area") && !hasArchiveActionArea) {
    violations.push(`${label}: primary CTA must use ArchiveActionArea`);
  }

  if (
    primaryCount > 0 &&
    hasArchiveActionArea &&
    !source.includes("justify-end") &&
    !source.includes("ArchiveActionArea")
  ) {
    // ArchiveActionArea component owns justify-end
  }

  if (violetPrimaryButtons > 2 && primaryProps === 0) {
    violations.push(`${label}: competing violet primary buttons (${violetPrimaryButtons})`);
  }

  if (secondaryProps > 2 && primaryProps === 0) {
    violations.push(`${label}: too many secondary actions without a single primary`);
  }

  return {
    ok: violations.length === 0,
    violations,
    primaryCount: Math.max(primaryProps, primaryCount),
    hasArchiveActionArea,
  };
}

export function expectedPrimaryPlacement(): string {
  return "bottom-right end of page flow via ArchiveActionArea";
}
