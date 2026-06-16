import { buildArchiveMaturityEngineInput, ArchiveMaturityEngine } from "@/lib/archive/archive-maturity-engine";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildArchiveAccuracyView } from "@/lib/archive/archive-accuracy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveHealthLabel } from "@/types/archive-state-object";
import type { JournalEntry } from "@/types/journal";

/** Internal signals → one health line for users. */
export function resolveArchiveHealthV3(
  entriesInput?: JournalEntry[],
): ArchiveHealthLabel {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const reputation = buildArchiveReputationView(entries);
  const accuracy = buildArchiveAccuracyView(entries);
  const maturity = ArchiveMaturityEngine.buildView(
    buildArchiveMaturityEngineInput(entries),
  );

  const repRank =
    reputation?.level === "very_high" || reputation?.level === "high"
      ? 3
      : reputation?.level === "moderate" || reputation?.level === "developing"
        ? 2
        : 1;

  const accuracyChallenged =
    accuracy?.beliefs.some((b) => b.status === "challenged") ?? false;
  const maturityEarly =
    maturity.stage === "starting" || maturity.stage === "building_evidence";

  if (accuracyChallenged || (repRank <= 1 && maturityEarly)) {
    return "Uncertain";
  }
  if (repRank >= 3 && !maturityEarly) {
    return "Strong";
  }
  return "Developing";
}
