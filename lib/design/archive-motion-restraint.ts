import type { ArchiveTransitionMode } from "@/components/archive/ArchiveTransition";

/** Motion that explains state change — allowed on archive surfaces. */
export const ARCHIVE_STATE_CHANGE_MOTION: ArchiveTransitionMode[] = [
  "movement",
  "timeline",
  "confidence",
];

/** Decorative motion — disallowed on empty states and static chrome. */
export const ARCHIVE_DECORATIVE_MOTION: ArchiveTransitionMode[] = ["fade", "card"];

export const ARCHIVE_MOTION_MAX_FADE_USES_PER_FILE = 2;
