export const ARCHIVE_REDUCTION_MORE_LABEL = "Show more archive detail";

export const ARCHIVE_REDUCTION_MAX_VISIBLE = 3;

export type ArchiveReductionSectionId =
  | "reputation"
  | "trust"
  | "movement"
  | "timeline"
  | "evidence"
  | "meaning"
  | "ownership";

/** Belief-centric archive order — timeline central before evidence. */
export const ARCHIVE_BELIEF_CENTRIC_PRIORITY: ArchiveReductionSectionId[] = [
  "reputation",
  "trust",
  "movement",
  "timeline",
  "evidence",
];

export const ARCHIVE_BELIEF_CENTRIC_MAX_VISIBLE = 4;

/** Higher items surface first when reducing noise. */
export const ARCHIVE_REDUCTION_PRIORITY: ArchiveReductionSectionId[] = [
  "reputation",
  "trust",
  "movement",
  "timeline",
  "evidence",
  "meaning",
  "ownership",
];

export function partitionArchiveSections<T extends { id: ArchiveReductionSectionId }>(
  sections: T[],
  options?: { priority?: ArchiveReductionSectionId[]; maxVisible?: number },
): { visible: T[]; collapsed: T[] } {
  const priority = options?.priority ?? ARCHIVE_REDUCTION_PRIORITY;
  const maxVisible = options?.maxVisible ?? ARCHIVE_REDUCTION_MAX_VISIBLE;
  const byId = new Map(sections.map((section) => [section.id, section]));
  const ordered = priority.map((id) => byId.get(id)).filter(
    (section): section is T => Boolean(section),
  );
  const visible = ordered.slice(0, maxVisible);
  const visibleIds = new Set(visible.map((section) => section.id));
  const collapsed = ordered.filter((section) => !visibleIds.has(section.id));
  return { visible, collapsed };
}
