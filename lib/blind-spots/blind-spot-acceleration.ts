import { buildBlindSpotReview } from "@/lib/blind-spots/blind-spot-review";
import { buildEmergingPatterns } from "@/lib/blind-spots/emerging-patterns";
import { syncPredictionCandidates } from "@/lib/blind-spots/prediction-detection";
import { buildPredictionReview } from "@/lib/blind-spots/prediction-review";
import type { BlindSpotAccelerationReport } from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

/** Full blind spot acceleration payload for the review page. */
export function buildBlindSpotAccelerationReport(
  entries: JournalEntry[],
): BlindSpotAccelerationReport {
  const candidates = syncPredictionCandidates(entries);

  return {
    emergingPatterns: buildEmergingPatterns(entries),
    mainReview: buildBlindSpotReview(entries),
    predictionReview: buildPredictionReview(candidates, entries),
  };
}
