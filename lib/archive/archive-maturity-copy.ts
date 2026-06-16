import type { ArchiveMaturityStage } from "@/types/archive-maturity";

export const ARCHIVE_MATURITY_LABEL = "Archive maturity";

export const ARCHIVE_MATURITY_TAGLINE =
  "More evidence makes beliefs easier to challenge.";

export const ARCHIVE_MATURITY_STAGE_LABEL: Record<ArchiveMaturityStage, string> = {
  starting: "Starting",
  building_evidence: "Building evidence",
  beliefs_forming: "Beliefs forming",
  beliefs_changing: "Beliefs changing",
  mature_archive: "Mature archive",
};
