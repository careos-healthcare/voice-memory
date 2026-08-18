/**
 * Surface Reduction v2 — every major archive surface must state its contribution.
 */
export type ArchiveFeatureId =
  | "ArchiveCommandCenter"
  | "ArchiveHomeScore"
  | "WhyOpenArchiveToday"
  | "ArchiveReputationCard"
  | "WhyTheArchiveTrustsThis"
  | "ArchiveReputationMovement"
  | "SessionMovementSummary"
  | "TheoryChangeFeed"
  | "BeliefDossier"
  | "EvidenceLocker"
  | "BeliefChangeTimeline"
  | "ArchiveContradictionHistory"
  | "ArchiveAccuracyTracker"
  | "BeliefSurvivalCard"
  | "BlindSpotReview"
  | "ReflectionLog"
  | "EvidenceSearch"
  | "ArchiveDetailHub";

export interface ArchiveFeatureJustification {
  surface: ArchiveFeatureId;
  archiveContributionReason: string;
}

export const ARCHIVE_FEATURE_JUSTIFICATION: Record<
  ArchiveFeatureId,
  ArchiveFeatureJustification
> = {
  ArchiveCommandCenter: {
    surface: "ArchiveCommandCenter",
    archiveContributionReason:
      "Answers what the archive believes, what changed, and why to trust it on one screen.",
  },
  ArchiveHomeScore: {
    surface: "ArchiveHomeScore",
    archiveContributionReason:
      "Summarizes current belief, reputation, and change at a glance.",
  },
  WhyOpenArchiveToday: {
    surface: "WhyOpenArchiveToday",
    archiveContributionReason: "Explains why to open the archive today before scrolling.",
  },
  ArchiveReputationCard: {
    surface: "ArchiveReputationCard",
    archiveContributionReason: "Explains why the archive trusts a belief.",
  },
  WhyTheArchiveTrustsThis: {
    surface: "WhyTheArchiveTrustsThis",
    archiveContributionReason: "Shows the evidence basis for trust in the current belief.",
  },
  ArchiveReputationMovement: {
    surface: "ArchiveReputationMovement",
    archiveContributionReason: "Shows how archive confidence and reputation shifted.",
  },
  SessionMovementSummary: {
    surface: "SessionMovementSummary",
    archiveContributionReason: "Summarizes what changed after a reflection or visit.",
  },
  TheoryChangeFeed: {
    surface: "TheoryChangeFeed",
    archiveContributionReason: "Lists belief and evidence changes since last visit.",
  },
  BeliefDossier: {
    surface: "BeliefDossier",
    archiveContributionReason:
      "Deep view of one belief — evidence, trust, and why the archive holds it.",
  },
  EvidenceLocker: {
    surface: "EvidenceLocker",
    archiveContributionReason: "Shows the observations that support or challenge beliefs.",
  },
  BeliefChangeTimeline: {
    surface: "BeliefChangeTimeline",
    archiveContributionReason: "Shows how beliefs changed over time.",
  },
  ArchiveContradictionHistory: {
    surface: "ArchiveContradictionHistory",
    archiveContributionReason: "Shows when reflections challenged the archive view.",
  },
  ArchiveAccuracyTracker: {
    surface: "ArchiveAccuracyTracker",
    archiveContributionReason: "Shows whether the archive's view matched later evidence.",
  },
  BeliefSurvivalCard: {
    surface: "BeliefSurvivalCard",
    archiveContributionReason: "Shows which beliefs persisted or faded across evidence.",
  },
  BlindSpotReview: {
    surface: "BlindSpotReview",
    archiveContributionReason: "Explains why the archive believes a recurring pattern.",
  },
  ReflectionLog: {
    surface: "ReflectionLog",
    archiveContributionReason:
      "Lists stored reflections only — no duplicate archive interpretation.",
  },
  EvidenceSearch: {
    surface: "EvidenceSearch",
    archiveContributionReason: "Finds entries that may support or challenge beliefs.",
  },
  ArchiveDetailHub: {
    surface: "ArchiveDetailHub",
    archiveContributionReason:
      "Single entry for secondary archive tools so primary surfaces stay uncluttered.",
  },
};

export function justificationFor(surface: ArchiveFeatureId): string {
  return ARCHIVE_FEATURE_JUSTIFICATION[surface].archiveContributionReason;
}
