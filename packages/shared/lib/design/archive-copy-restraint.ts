/**
 * Archive Taste v1 — one headline + one supporting sentence before interaction.
 */

import {
  ARCHIVE_NAV_ARCHIVE_MEANING,
  DISCOVER_PAGE_HEADING,
  DISCOVER_PAGE_SUBHEADLINE,
  MEMORY_PAGE_UTILITY_TITLE,
} from "@/lib/product/archive-product-copy";
import {
  ARCHIVE_COMMAND_CENTER_TAGLINE,
  PAGE_TITLE_ARCHIVE,
} from "@/lib/product/product-simplification-copy";

export type ArchiveCopyRestraintSurface = "archive" | "changes" | "detail" | "account";

export type ArchiveSectionCopySpec = {
  /** Single most important thing the user needs to know. */
  headline: string;
  /** At most one supporting sentence before interaction. */
  support: string;
};

export const ARCHIVE_COPY_RESTRAINT: Record<
  ArchiveCopyRestraintSurface,
  ArchiveSectionCopySpec
> = {
  archive: {
    headline: PAGE_TITLE_ARCHIVE,
    support: ARCHIVE_COMMAND_CENTER_TAGLINE,
  },
  changes: {
    headline: DISCOVER_PAGE_HEADING,
    support: DISCOVER_PAGE_SUBHEADLINE,
  },
  detail: {
    headline: "Archive detail",
    support: "Advanced archive information when you want to inspect evidence.",
  },
  account: {
    headline: "Account",
    support: "Encrypted backup and continuity for your archive.",
  },
};

/** Identity eyebrows — one line, no duplicate archive definitions. */
export const ARCHIVE_SURFACE_EYEBROWS: Record<ArchiveCopyRestraintSurface, string> = {
  archive: ARCHIVE_NAV_ARCHIVE_MEANING,
  changes: "Archive Activity",
  detail: ARCHIVE_NAV_ARCHIVE_MEANING,
  account: "Archive continuity",
};

export const MEMORY_LOG_COPY: ArchiveSectionCopySpec = {
  headline: MEMORY_PAGE_UTILITY_TITLE,
  support: "Reflections on this device.",
};

/** Phrases disallowed on post-onboarding archive surfaces. */
export const ARCHIVE_COPY_BANNED_PATTERNS: RegExp[] = [
  /why this works/i,
  /not a separate product/i,
  /not a verdict/i,
  /the value is not one answer/i,
  /feature tour/i,
];

export function passesArchiveCopyRestraint(text: string): boolean {
  return !ARCHIVE_COPY_BANNED_PATTERNS.some((re) => re.test(text));
}
