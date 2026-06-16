/**
 * Archive Belief Centric Architecture — which surface owns which questions.
 */

export type ArchiveOwnershipQuestion =
  | "belief"
  | "why_belief"
  | "change"
  | "trust"
  | "evidence"
  | "timeline"
  | "entries"
  | "settings";

export type ArchiveSurfaceOwner =
  | "archive"
  | "discover"
  | "memory"
  | "account"
  | "archive_detail";

export const ARCHIVE_SURFACE_OWNERSHIP: Record<
  ArchiveSurfaceOwner,
  readonly ArchiveOwnershipQuestion[]
> = {
  archive: ["belief", "why_belief", "change", "trust", "evidence", "timeline"],
  discover: ["change"],
  memory: ["entries"],
  account: ["settings"],
  archive_detail: [],
};

/** Components forbidden on each owner (drift detection for validators). */
export const SURFACE_OWNERSHIP_FORBIDDEN: Record<ArchiveSurfaceOwner, readonly string[]> = {
  archive: [],
  discover: [
    "ArchiveBeliefCard",
    "WhyTheArchiveTrustsThis",
    "BeliefDossier",
    "EvidenceLocker",
    "ArchiveBeliefEvidenceSection",
    "ArchiveAccuracyTracker",
    "BeliefSurvivalCard",
  ],
  memory: [
    "ArchiveBeliefCard",
    "ArchiveReputationCard",
    "WhyTheArchiveTrustsThis",
    "SessionMovementSummary",
    "ArchiveValueBanner",
    "CurrentArchiveBeliefStrip",
  ],
  account: ["ArchiveCommandCenter", "TheoryChangeFeed"],
  archive_detail: [],
};

export function surfaceOwns(
  owner: ArchiveSurfaceOwner,
  question: ArchiveOwnershipQuestion,
): boolean {
  return ARCHIVE_SURFACE_OWNERSHIP[owner].includes(question);
}

export function assertSurfaceOwnership(
  owner: ArchiveSurfaceOwner,
  fileContents: string,
): string[] {
  const violations: string[] = [];
  for (const token of SURFACE_OWNERSHIP_FORBIDDEN[owner]) {
    if (fileContents.includes(token)) {
      violations.push(`${owner} must not render ${token}`);
    }
  }
  return violations;
}
