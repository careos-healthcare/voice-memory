import {
  readEvolvingUnderstandingEvents,
  readEvolvingUnderstandingState,
} from "@/lib/metrics/evolving-understanding-events";
import type { EvolvingUnderstandingReport } from "@/types/evolving-understanding";

export const EVOLVING_UNDERSTANDING_MAIN_QUESTION =
  "Do users return because the archive view may have changed?";

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function countEvent(name: string): number {
  return readEvolvingUnderstandingEvents().filter((e) => e.name === name).length;
}

export function buildEvolvingUnderstandingReport(): EvolvingUnderstandingReport {
  const events = readEvolvingUnderstandingEvents();
  const state = readEvolvingUnderstandingState();

  const firstBlindSpotSeenCount = countEvent("first_working_theory_seen");
  const evolvingViewCardSeenCount = countEvent("evolving_view_card_seen");
  const whatHappensNextClickCount = countEvent("what_happens_next_clicked");
  const discoverAfterFirstBlindSpotCount = countEvent(
    "discover_after_first_blind_spot_opened",
  );
  const returnedToCheckArchiveViewCount = countEvent("returned_to_check_archive_view");

  const discoverAfterFirstBlindSpotRate = pct(
    discoverAfterFirstBlindSpotCount,
    firstBlindSpotSeenCount,
  );
  const returnedToCheckArchiveViewRate = pct(
    returnedToCheckArchiveViewCount,
    firstBlindSpotSeenCount,
  );
  const whatHappensNextClickRate = pct(
    whatHappensNextClickCount,
    firstBlindSpotSeenCount,
  );

  const lines: string[] = [
    `First working theory seen: ${firstBlindSpotSeenCount}`,
    `Evolving view card seen: ${evolvingViewCardSeenCount}`,
    `What happens next clicked: ${whatHappensNextClickCount}${
      whatHappensNextClickRate !== null ? ` (${whatHappensNextClickRate}% of first theory)` : ""
    }`,
    `Discover after first blind spot: ${discoverAfterFirstBlindSpotCount}${
      discoverAfterFirstBlindSpotRate !== null
        ? ` (${discoverAfterFirstBlindSpotRate}%)`
        : ""
    }`,
    `Returned to check archive view (≥24h): ${returnedToCheckArchiveViewCount}${
      returnedToCheckArchiveViewRate !== null
        ? ` (${returnedToCheckArchiveViewRate}%)`
        : ""
    }`,
  ];

  if (state.firstWorkingTheorySeenAt) {
    lines.push(`First theory timestamp: ${state.firstWorkingTheorySeenAt}`);
  }

  return {
    mainQuestion: EVOLVING_UNDERSTANDING_MAIN_QUESTION,
    firstBlindSpotSeenCount,
    evolvingViewCardSeenCount,
    whatHappensNextClickCount,
    discoverAfterFirstBlindSpotCount,
    returnedToCheckArchiveViewCount,
    discoverAfterFirstBlindSpotRate,
    returnedToCheckArchiveViewRate,
    whatHappensNextClickRate,
    lines,
  };
}
