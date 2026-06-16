/**
 * Archive Experience typography — only these sizes on archive surfaces.
 */

export const ARCHIVE_TYPO = {
  hero: "text-3xl font-semibold tracking-tight text-white",
  pageTitle: "text-2xl font-semibold tracking-tight text-white",
  sectionTitle: "text-sm font-medium text-zinc-300",
  cardTitle: "text-sm font-medium text-zinc-200",
  body: "text-sm leading-relaxed text-zinc-400",
  caption: "text-xs leading-relaxed text-zinc-500",
  eyebrow: "text-xs uppercase tracking-[0.2em] text-violet-200",
} as const;

export type ArchiveTypoRole = keyof typeof ARCHIVE_TYPO;

/** Roles allowed on archive experience pages (no ad-hoc text-* sizes). */
export const ARCHIVE_TYPO_ROLES: ArchiveTypoRole[] = [
  "hero",
  "pageTitle",
  "sectionTitle",
  "cardTitle",
  "body",
  "caption",
  "eyebrow",
];

export function archiveTypo(role: ArchiveTypoRole): string {
  return ARCHIVE_TYPO[role];
}
