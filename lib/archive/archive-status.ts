import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  ARCHIVE_LIVING_STATUS_LABEL,
  ARCHIVE_LIVING_STATUS_LINE,
  ARCHIVE_STATUS_CARD_TITLE,
} from "@/lib/archive/living-archive-copy";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { archiveReputationLevelRank } from "@/lib/archive/archive-reputation";
import { buildArchiveStateDelta } from "@/lib/archive/archive-state-snapshot";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveLivingStatus, ArchiveStatusView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function evidenceVelocity(entries: JournalEntry[]): number {
  if (entries.length < 2) return 0;
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  const recent = sorted.filter((e) => {
    const days =
      (Date.now() - new Date(e.createdAt).getTime()) / (1000 * 60 * 60 * 24);
    return days <= 7;
  });
  return recent.length;
}

export function deriveArchiveLivingStatus(
  entriesInput?: JournalEntry[],
): ArchiveLivingStatus {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  const reputation = buildArchiveReputationView(entries);
  const delta = buildArchiveStateDelta(entries);
  const velocity = evidenceVelocity(entries);

  if (entries.length < 3 || !belief) return "learning";

  const contradictions = belief.evidence.contradictingQuotes.length;
  const confidenceDelta =
    delta?.rows.find((r) => r.kind === "confidence") ?? null;

  if (belief.status === "under_review" && contradictions === 0) {
    return velocity >= 2 ? "investigating" : "investigating";
  }

  if (belief.status === "weakening" || delta?.rows.some((r) => r.kind === "belief")) {
    return "revising";
  }

  if (contradictions > 0 && belief.confidence < 55) {
    return "uncertain";
  }

  if (
    belief.status === "strengthening" ||
    (confidenceDelta && confidenceDelta.now > confidenceDelta.then)
  ) {
    return "strengthening";
  }

  const repRank = reputation ? archiveReputationLevelRank(reputation.level) : 0;
  if (!delta?.hasChanges && repRank >= 2 && contradictions === 0) {
    return "stable";
  }

  if (velocity >= 3 && belief.status === "under_review") return "investigating";

  return "investigating";
}

export function buildArchiveStatusView(
  entriesInput?: JournalEntry[],
): ArchiveStatusView {
  const status = deriveArchiveLivingStatus(entriesInput);
  return {
    status,
    title: ARCHIVE_STATUS_CARD_TITLE,
    label: ARCHIVE_LIVING_STATUS_LABEL[status],
    line: ARCHIVE_LIVING_STATUS_LINE[status],
  };
}
