import { readBlindSpotAnalyticsEvents } from "@/lib/blind-spots/blind-spot-events";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { BLIND_SPOT_EVENTS } from "@/lib/blind-spots/blind-spot-events";
import {
  ARCHIVE_AS_PRODUCT_EVENT_NAMES,
  readPostFiveFirstSurfaceCounts,
} from "@/lib/metrics/archive-as-product-events";
import { readLocalEvents } from "@/lib/local-analytics";
import { readEvolvingUnderstandingEvents } from "@/lib/metrics/evolving-understanding-events";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { readTheoryCuriosityRecords } from "@/lib/metrics/theory-curiosity";
import { readAllTheoryEvents, THEORY_EVENTS } from "@/lib/theories/theory-events";
import type { BlindSpotReaction } from "@/types/blind-spot";
import type { FounderTestSession } from "@/types/founder-test";

/** Read existing local signals only — no new analysis. */
export function readFounderTestDeviceHints(): Partial<FounderTestSession> {
  const reflectionCount = countCompletedReflections();
  const openedBlindSpots = readBlindSpotAnalyticsEvents().some(
    (e) => e.name === BLIND_SPOT_EVENTS.blindSpotOpened,
  );
  const openedDiscover = readAllTheoryEvents().some(
    (e) => e.name === THEORY_EVENTS.discoverOpened,
  );

  const feedback = readAllBlindSpotFeedback().sort((a, b) => a.at.localeCompare(b.at));
  const firstBlindSpotReaction = feedback[0]?.reaction as BlindSpotReaction | undefined;

  const curiosityRecords = readTheoryCuriosityRecords();
  const latestCuriosity = curiosityRecords[curiosityRecords.length - 1];
  const returnedToCheckArchiveView = readEvolvingUnderstandingEvents().some(
    (e) => e.name === "returned_to_check_archive_view",
  );

  const postFive = readPostFiveFirstSurfaceCounts();
  const openedArchiveBeforeDiscoverPostFive =
    postFive.total > 0 ? postFive.archiveFirst > postFive.discoverFirst : undefined;

  return {
    reflectionCount,
    reachedFiveReflections: reflectionCount >= 5,
    openedBlindSpots,
    openedDiscover,
    firstBlindSpotReaction,
    theoryCuriosityAnswer: latestCuriosity?.answer,
    returnedToCheckArchiveView: returnedToCheckArchiveView || undefined,
    openedArchiveBeforeDiscoverPostFive,
    voluntaryArchiveReturn: readLocalEvents().some(
      (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.voluntaryArchiveReturn,
    )
      ? true
      : undefined,
  };
}
