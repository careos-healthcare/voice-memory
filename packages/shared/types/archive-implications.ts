/** Archive Implications v1 — significance without advice. */

export const ARCHIVE_IMPLICATION_TYPE_IDS = [
  "LONG_RUNNING",
  "STRENGTHENING",
  "WEAKENING",
  "LIFE_AREA_CONCENTRATION",
  "CROSS_AREA_PATTERN",
  "CONFLICTING_EVIDENCE",
  "PERSISTENT_PATTERN",
  "NEW_PATTERN",
] as const;

export type ArchiveImplicationTypeId = (typeof ARCHIVE_IMPLICATION_TYPE_IDS)[number];

export interface ArchiveImplication {
  id: string;
  type: ArchiveImplicationTypeId;
  /** User-facing significance line — descriptive, not prescriptive. */
  text: string;
  priority: number;
}

export interface ArchiveImplicationsView {
  theoryId: string;
  implications: ArchiveImplication[];
  /** Top 1–3 lines for cards and “why should I care”. */
  headlineLines: string[];
}
