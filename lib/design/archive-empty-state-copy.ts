export type ArchiveEmptyStateSpec = {
  headline: string;
  body: string;
  ctaLabel: string | null;
  /** When UI imports this export name instead of inlining strings. */
  constantRef?: string;
};

export const ARCHIVE_EMPTY_NO_BELIEF: ArchiveEmptyStateSpec = {
  constantRef: "ARCHIVE_EMPTY_NO_BELIEF",
  headline: "No archive belief yet",
  body: "Record another moment.",
  ctaLabel: "Record",
};

export const ARCHIVE_EMPTY_TIMELINE: ArchiveEmptyStateSpec = {
  headline: "No belief changes yet",
  body: "A few more moments unlock the timeline.",
  ctaLabel: null,
};
