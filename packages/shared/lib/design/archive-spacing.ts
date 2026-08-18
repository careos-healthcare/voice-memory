/**
 * Archive Experience spacing — XS through XL only.
 */

export const ARCHIVE_SPACE = {
  xs: "mt-1",
  sm: "mt-2",
  md: "mt-4",
  lg: "mt-6",
  xl: "mt-8",
  gapXs: "gap-1",
  gapSm: "gap-2",
  gapMd: "gap-4",
  gapLg: "gap-6",
  gapXl: "gap-8",
  sectionStack: "space-y-6",
  /** Extra breath between belief / trust / change / evidence blocks. */
  sectionBreath: "space-y-10",
  mainStack: "space-y-10",
  pagePad: "px-0",
} as const;

export type ArchiveSpaceToken = keyof typeof ARCHIVE_SPACE;

export const ARCHIVE_SPACE_TOKENS: ArchiveSpaceToken[] = [
  "xs",
  "sm",
  "md",
  "lg",
  "xl",
  "gapXs",
  "gapSm",
  "gapMd",
  "gapLg",
  "gapXl",
  "sectionStack",
  "mainStack",
  "pagePad",
];

/** Tailwind arbitrary spacing patterns disallowed on blueprint surfaces. */
export const FORBIDDEN_ARBITRARY_SPACING = /\b[mp][trblxy]?-\[[^\]]+\]/;

export function archiveSpace(token: ArchiveSpaceToken): string {
  return ARCHIVE_SPACE[token];
}
