/**
 * Visual gravity — what should dominate each archive surface.
 */

import {
  ARCHIVE_BLUEPRINT_SECTION_ORDER,
  type ArchiveBlueprintSectionId,
} from "@/lib/design/archive-page-grammar";

export const ARCHIVE_GRAVITY_ORDER = [
  "belief",
  "trust",
  "change",
  "evidence",
  "context",
] as const;

export type ArchiveGravityWeight = (typeof ARCHIVE_GRAVITY_ORDER)[number];

export { ARCHIVE_BLUEPRINT_SECTION_ORDER };
export type ArchiveBlueprintSection = ArchiveBlueprintSectionId;

const GRAVITY_RANK: Record<ArchiveGravityWeight, number> = {
  belief: 1,
  trust: 2,
  change: 3,
  evidence: 4,
  context: 5,
};

export function compareGravity(
  a: ArchiveGravityWeight,
  b: ArchiveGravityWeight,
): number {
  return GRAVITY_RANK[a] - GRAVITY_RANK[b];
}

export function assertBlueprintSectionOrder(sections: ArchiveBlueprintSection[]): boolean {
  let last = -1;
  for (const s of sections) {
    const idx = ARCHIVE_BLUEPRINT_SECTION_ORDER.indexOf(s);
    if (idx < last) return false;
    last = idx;
  }
  return true;
}

export const ARCHIVE_SURFACE_PRIMARY_QUESTION: Record<string, string> = {
  archive: "What does my archive believe?",
  discover: "What changed since my last visit?",
  blind_spots: "Why does the archive believe this?",
  memory: "What moments support the archive?",
  changes: "What archive changes need attention?",
};
