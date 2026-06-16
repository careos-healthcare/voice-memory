import { ARCHIVE_TYPO, ARCHIVE_TYPO_ROLES, type ArchiveTypoRole } from "@/lib/design/archive-typography";

/** Canonical title roles — no ad-hoc sizing on archive surfaces. */
export const HeroTitle = ARCHIVE_TYPO.hero;
export const PageTitle = ARCHIVE_TYPO.pageTitle;
export const SectionTitle = ARCHIVE_TYPO.sectionTitle;
export const CardTitle = ARCHIVE_TYPO.cardTitle;
export const Body = ARCHIVE_TYPO.body;
export const Caption = ARCHIVE_TYPO.caption;

export const ARCHIVE_TYPO_AUDIT_ROLES = [
  "HeroTitle",
  "PageTitle",
  "SectionTitle",
  "CardTitle",
  "Body",
  "Caption",
] as const;

const ROLE_TO_KEY: Record<(typeof ARCHIVE_TYPO_AUDIT_ROLES)[number], ArchiveTypoRole> = {
  HeroTitle: "hero",
  PageTitle: "pageTitle",
  SectionTitle: "sectionTitle",
  CardTitle: "cardTitle",
  Body: "body",
  Caption: "caption",
};

export function archiveTypoRoleClass(
  role: (typeof ARCHIVE_TYPO_AUDIT_ROLES)[number],
): string {
  return ARCHIVE_TYPO[ROLE_TO_KEY[role]];
}

/** Disallowed on archive experience surfaces. */
export const FORBIDDEN_ARCHIVE_TYPO_PATTERNS: RegExp[] = [
  /\btext-4xl\b/,
  /\btext-5xl\b/,
  /\btext-\[[0-9]+px\]/,
  /\btext-\[[0-9.]+rem\]/,
];

const ALLOWED_INLINE_TYPO = new Set([
  ...ARCHIVE_TYPO_ROLES.map((r) => ARCHIVE_TYPO[r]),
  "ARCHIVE_TYPO",
  "archiveTypo",
  "HeroTitle",
  "PageTitle",
  "SectionTitle",
  "CardTitle",
  "Body",
  "Caption",
]);

export type TypographyAuditResult = {
  ok: boolean;
  violations: string[];
};

export function auditArchiveTypography(source: string, label: string): TypographyAuditResult {
  const violations: string[] = [];

  for (const pattern of FORBIDDEN_ARCHIVE_TYPO_PATTERNS) {
    const hits = source.match(new RegExp(pattern.source, "g"));
    if (hits?.length) {
      violations.push(`${label}: forbidden typography ${hits.slice(0, 3).join(", ")}`);
    }
  }

  if (/\bMotionPageTitle\b/.test(source)) {
    violations.push(`${label}: use ArchivePageBlueprint identity + ARCHIVE_TYPO, not MotionPageTitle`);
  }

  const adHocHeadings = source.match(/<h[12][^>]*className="[^"]*text-(2xl|3xl|4xl)/g);
  if (adHocHeadings?.length) {
    const usesTypo = adHocHeadings.some((line) =>
      [...ALLOWED_INLINE_TYPO].some((token) => line.includes(token)),
    );
    if (!usesTypo) {
      violations.push(`${label}: ad-hoc heading size on archive surface`);
    }
  }

  return { ok: violations.length === 0, violations };
}
