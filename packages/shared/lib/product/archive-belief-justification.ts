/**
 * Archive Belief Centric — every feature must support belief, evidence, change, or trust.
 */
import type { ArchiveFeatureId } from "@/lib/product/archive-feature-justification";

export interface ArchiveBeliefFeatureJustification {
  surface: ArchiveFeatureId;
  supportsBelief: boolean;
  supportsEvidence: boolean;
  supportsChange: boolean;
  supportsTrust: boolean;
  archiveContributionReason: string;
  centrality: "core" | "supporting" | "candidate_for_hide";
}

function entry(
  surface: ArchiveFeatureId,
  flags: Pick<
    ArchiveBeliefFeatureJustification,
    "supportsBelief" | "supportsEvidence" | "supportsChange" | "supportsTrust" | "archiveContributionReason"
  >,
  centrality: ArchiveBeliefFeatureJustification["centrality"] = "core",
): ArchiveBeliefFeatureJustification {
  const active =
    flags.supportsBelief ||
    flags.supportsEvidence ||
    flags.supportsChange ||
    flags.supportsTrust;
  if (!active) {
    return {
      surface,
      ...flags,
      centrality: "candidate_for_hide",
    };
  }
  return { surface, ...flags, centrality };
}

export const ARCHIVE_BELIEF_FEATURE_JUSTIFICATION: Record<
  ArchiveFeatureId,
  ArchiveBeliefFeatureJustification
> = {
  ArchiveCommandCenter: entry(
    "ArchiveCommandCenter",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: true,
      archiveContributionReason:
        "Shows belief, reputation, trust, change, and timeline in one archive read.",
    },
  ),
  ArchiveHomeScore: entry(
    "ArchiveHomeScore",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: true,
      archiveContributionReason: "At-a-glance belief, reputation, and change.",
    },
  ),
  WhyOpenArchiveToday: entry(
    "WhyOpenArchiveToday",
    {
      supportsBelief: false,
      supportsEvidence: false,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Explains why to open the archive today.",
    },
    "supporting",
  ),
  ArchiveReputationCard: entry(
    "ArchiveReputationCard",
    {
      supportsBelief: false,
      supportsEvidence: false,
      supportsChange: false,
      supportsTrust: true,
      archiveContributionReason: "Explains how trustworthy the archive considers this belief.",
    },
  ),
  WhyTheArchiveTrustsThis: entry(
    "WhyTheArchiveTrustsThis",
    {
      supportsBelief: false,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: true,
      archiveContributionReason: "Shows why the archive trusts the current belief.",
    },
  ),
  ArchiveReputationMovement: entry(
    "ArchiveReputationMovement",
    {
      supportsBelief: false,
      supportsEvidence: false,
      supportsChange: true,
      supportsTrust: true,
      archiveContributionReason: "Shows reputation and confidence shifts over time.",
    },
  ),
  SessionMovementSummary: entry(
    "SessionMovementSummary",
    {
      supportsBelief: false,
      supportsEvidence: false,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Summarizes what changed in the archive.",
    },
  ),
  TheoryChangeFeed: entry(
    "TheoryChangeFeed",
    {
      supportsBelief: false,
      supportsEvidence: false,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Lists belief and evidence changes since last visit.",
    },
  ),
  BeliefDossier: entry(
    "BeliefDossier",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: true,
      archiveContributionReason: "Deep belief dossier with evidence and trust.",
    },
  ),
  EvidenceLocker: entry(
    "EvidenceLocker",
    {
      supportsBelief: false,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: false,
      archiveContributionReason: "Stores observations that support beliefs.",
    },
  ),
  BeliefChangeTimeline: entry(
    "BeliefChangeTimeline",
    {
      supportsBelief: true,
      supportsEvidence: false,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Shows how beliefs evolved over time.",
    },
  ),
  ArchiveContradictionHistory: entry(
    "ArchiveContradictionHistory",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Shows when evidence challenged beliefs.",
    },
    "supporting",
  ),
  ArchiveAccuracyTracker: entry(
    "ArchiveAccuracyTracker",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: true,
      archiveContributionReason: "Tracks whether archive views matched later evidence.",
    },
    "supporting",
  ),
  BeliefSurvivalCard: entry(
    "BeliefSurvivalCard",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: false,
      archiveContributionReason: "Shows which beliefs persisted across evidence.",
    },
    "supporting",
  ),
  BlindSpotReview: entry(
    "BlindSpotReview",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: true,
      archiveContributionReason: "Evidence for why the archive currently believes.",
    },
    "supporting",
  ),
  ReflectionLog: entry(
    "ReflectionLog",
    {
      supportsBelief: false,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: false,
      archiveContributionReason: "Reflection storage only — no duplicate interpretation.",
    },
    "supporting",
  ),
  EvidenceSearch: entry(
    "EvidenceSearch",
    {
      supportsBelief: false,
      supportsEvidence: true,
      supportsChange: false,
      supportsTrust: false,
      archiveContributionReason: "Finds evidence entries.",
    },
    "supporting",
  ),
  ArchiveDetailHub: entry(
    "ArchiveDetailHub",
    {
      supportsBelief: true,
      supportsEvidence: true,
      supportsChange: true,
      supportsTrust: true,
      archiveContributionReason: "Hub for demoted belief, evidence, change, and trust tools.",
    },
    "supporting",
  ),
};

export function beliefJustificationFor(surface: ArchiveFeatureId): ArchiveBeliefFeatureJustification {
  return ARCHIVE_BELIEF_FEATURE_JUSTIFICATION[surface];
}

export function featuresMissingBeliefCentricSupport(): ArchiveFeatureId[] {
  return (Object.keys(ARCHIVE_BELIEF_FEATURE_JUSTIFICATION) as ArchiveFeatureId[]).filter(
    (id) => ARCHIVE_BELIEF_FEATURE_JUSTIFICATION[id].centrality === "candidate_for_hide",
  );
}
