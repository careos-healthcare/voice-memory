"use client";

import { ArchiveAccuracyTracker } from "@/archived-components/_archived/archive/ArchiveAccuracyTracker";
import { ArchiveContradictionHistory } from "@/archived-components/_archived/archive/ArchiveContradictionHistory";
import { ArchiveOwnershipPanel } from "@/archived-components/_archived/archive/ArchiveOwnershipPanel";
import { ArchiveReputationCard } from "@/archived-components/_archived/archive/ArchiveReputationCard";
import { BeliefSurvivalCard } from "@/archived-components/_archived/archive/BeliefSurvivalCard";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  ARCHIVE_ADVANCED_DETAIL_DESCRIPTION,
  ARCHIVE_ADVANCED_DETAIL_EYEBROW,
  DISCLOSURE_ADVANCED_CONTINUITY,
  DISCLOSURE_ADVANCED_CONTRADICTIONS,
  DISCLOSURE_ADVANCED_SIGNALS,
  DISCLOSURE_ADVANCED_TRUST,
} from "@/lib/archive/archive-disclosure-copy";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

type AdvancedArchiveDetailProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** L3 only — advanced inspection behind Archive detail. */
export function AdvancedArchiveDetail({
  entriesOverride,
  className = "",
}: AdvancedArchiveDetailProps) {
  const hydrated = useClientHydrated();
  if (!hydrated) return null;

  const belief = buildArchiveBeliefView(entriesOverride);
  if (!belief) return null;

  return (
    <div
      className={`space-y-4 ${className}`}
      data-testid="advanced-archive-detail"
      data-archive-disclosure-surface="L3"
    >
      <header>
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
          {ARCHIVE_ADVANCED_DETAIL_EYEBROW}
        </p>
        <p className={`${ARCHIVE_TYPO.caption} mt-2`}>{ARCHIVE_ADVANCED_DETAIL_DESCRIPTION}</p>
      </header>

      <ArchiveReputationCard
        entriesOverride={entriesOverride}
        titleOverride={DISCLOSURE_ADVANCED_TRUST}
      />
      <ArchiveAccuracyTracker
        entriesOverride={entriesOverride}
        titleOverride={DISCLOSURE_ADVANCED_SIGNALS}
      />
      <BeliefSurvivalCard
        entriesOverride={entriesOverride}
        theoryId={belief.theoryId}
        titleOverride={DISCLOSURE_ADVANCED_CONTINUITY}
      />
      <ArchiveContradictionHistory
        entriesOverride={entriesOverride}
        theoryId={belief.theoryId}
        titleOverride={DISCLOSURE_ADVANCED_CONTRADICTIONS}
      />
      <ArchiveOwnershipPanel />
    </div>
  );
}
