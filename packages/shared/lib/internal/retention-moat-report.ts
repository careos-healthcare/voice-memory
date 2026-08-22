import { countArchiveAssetEvent, ARCHIVE_ASSET_EVENT_NAMES } from "@/lib/metrics/archive-asset-value-events";
import { countArchiveBeliefEvent, ARCHIVE_BELIEF_EVENT_NAMES } from "@/lib/metrics/archive-belief-events";
import { countArchiveMaturityEvent, ARCHIVE_MATURITY_EVENT_NAMES } from "@/lib/metrics/archive-maturity-events";
import { countHardToReproduceProofEvent, HARD_TO_REPRODUCE_EVENT_NAMES } from "@/lib/metrics/hard-to-reproduce-proof-events";
import {
  countSessionMovementSummaryEvent,
  SESSION_MOVEMENT_EVENT_NAMES,
} from "@/lib/metrics/session-movement-summary-events";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildArchiveMaturityView } from "@/lib/archive/archive-maturity";
import { getMemoryEligibleEntries } from "@/lib/storage";

export interface RetentionMoatReport {
  mainQuestion: string;
  movementSummarySeen: number;
  movementSummaryExpanded: number;
  archiveMaturitySeen: number;
  archiveMaturityClicked: number;
  archiveMaturityStage: string;
  archiveMaturityPercent: number;
  archiveAssetSeen: number;
  hardToReproduceSeen: number;
  hardToReproduceExpanded: number;
  discoverOpened: number;
  archiveBeliefViewed: number;
  returnedToCheckArchive: number;
  livingSystemSignals: string[];
}

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

export function buildRetentionMoatReport(): RetentionMoatReport {
  const maturity = buildArchiveMaturityView(getMemoryEligibleEntries());
  const movementSeen = countSessionMovementSummaryEvent(SESSION_MOVEMENT_EVENT_NAMES.seen);
  const beliefViewed = countArchiveBeliefEvent(ARCHIVE_BELIEF_EVENT_NAMES.viewed);
  const discoverOpened = countNamed("discover_opened");
  const returnedToCheck = countNamed("returned_to_check_archive_view");

  const livingSystemSignals: string[] = [];
  if (movementSeen >= 3) livingSystemSignals.push("Movement summary seen repeatedly");
  if (discoverOpened >= 2 && beliefViewed >= 1) {
    livingSystemSignals.push("Discover + belief card engagement");
  }
  if (returnedToCheck >= 1) livingSystemSignals.push("Explicit return-to-check archive");
  if (maturity.percent >= 40) livingSystemSignals.push("Archive maturity past early build");

  return {
    mainQuestion: "Are users treating the archive as a living system?",
    movementSummarySeen: movementSeen,
    movementSummaryExpanded: countSessionMovementSummaryEvent(
      SESSION_MOVEMENT_EVENT_NAMES.expanded,
    ),
    archiveMaturitySeen: countArchiveMaturityEvent(ARCHIVE_MATURITY_EVENT_NAMES.seen),
    archiveMaturityClicked: countArchiveMaturityEvent(ARCHIVE_MATURITY_EVENT_NAMES.clicked),
    archiveMaturityStage: maturity.stageLabel,
    archiveMaturityPercent: maturity.percent,
    archiveAssetSeen: countArchiveAssetEvent(ARCHIVE_ASSET_EVENT_NAMES.seen),
    hardToReproduceSeen: countHardToReproduceProofEvent(HARD_TO_REPRODUCE_EVENT_NAMES.seen),
    hardToReproduceExpanded: countHardToReproduceProofEvent(
      HARD_TO_REPRODUCE_EVENT_NAMES.expanded,
    ),
    discoverOpened,
    archiveBeliefViewed: beliefViewed,
    returnedToCheckArchive: returnedToCheck,
    livingSystemSignals,
  };
}
