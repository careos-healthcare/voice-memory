/** Progressive Archive Disclosure v1 — user-visible complexity tiers. */

export type ArchiveDisclosureLevel = "L1_BASIC" | "L2_ENGAGED" | "L3_ADVANCED";

export type ArchiveDisclosureInput = {
  reflectionCount: number;
  archiveVisitCount: number;
  archiveDetailOpened: boolean;
};

export type ArchiveDisclosureResolution = {
  level: ArchiveDisclosureLevel;
  reflectionCount: number;
  archiveVisitCount: number;
  reasons: string[];
};
