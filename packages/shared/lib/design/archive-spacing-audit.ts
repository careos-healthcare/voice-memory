import {
  ARCHIVE_SPACE,
  ARCHIVE_SPACE_TOKENS,
  FORBIDDEN_ARBITRARY_SPACING,
} from "@/lib/design/archive-spacing";

/** Allowed spacing scale on archive surfaces. */
export const ARCHIVE_SPACING_SCALE = {
  XS: ARCHIVE_SPACE.xs,
  S: ARCHIVE_SPACE.sm,
  M: ARCHIVE_SPACE.md,
  L: ARCHIVE_SPACE.lg,
  XL: ARCHIVE_SPACE.xl,
} as const;

export type ArchiveSpacingAuditResult = {
  ok: boolean;
  violations: string[];
};

const ALLOWED_MARGIN_TOKENS = new Set([
  "mt-1",
  "mt-2",
  "mt-4",
  "mt-6",
  "mt-8",
  "mb-1",
  "mb-2",
  "mb-3",
  "mb-4",
  "mb-6",
  "mb-8",
  "gap-1",
  "gap-2",
  "gap-4",
  "gap-6",
  "gap-8",
  "space-y-6",
  "space-y-8",
  "px-4",
  "pb-24",
  "sm:px-6",
]);

export function auditArchiveSpacing(source: string, label: string): ArchiveSpacingAuditResult {
  const violations: string[] = [];

  const arbitrary = source.match(FORBIDDEN_ARBITRARY_SPACING);
  if (arbitrary?.length) {
    violations.push(
      `${label}: arbitrary spacing ${[...new Set(arbitrary)].slice(0, 4).join(", ")}`,
    );
  }

  const suspiciousMargins = source.match(/\b(?:mt|mb|pt|pb)-(?:1[0-9]|[2-9][0-9])\b/g);
  if (suspiciousMargins?.length) {
    const offScale = suspiciousMargins.filter((t) => !ALLOWED_MARGIN_TOKENS.has(t));
    if (offScale.length) {
      violations.push(`${label}: off-scale spacing ${[...new Set(offScale)].slice(0, 3).join(", ")}`);
    }
  }

  if (/\bmt-16\b/.test(source) && label.includes("account")) {
    violations.push(`${label}: mt-16 — use ARCHIVE_SPACE (XL) instead`);
  }

  if (!source.includes("ARCHIVE_SPACE") && source.includes("ArchivePageBlueprint")) {
    violations.push(`${label}: archive blueprint surface should use ARCHIVE_SPACE tokens`);
  }

  return { ok: violations.length === 0, violations };
}

export function archiveSpacingTokensPresent(): boolean {
  return ARCHIVE_SPACE_TOKENS.length >= 5;
}
