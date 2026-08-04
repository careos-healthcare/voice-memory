import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type {
  BlindSpotReviewChangeLine,
  BlindSpotReviewChanges,
  BlindSpotReviewSnapshot,
} from "@/types/blind-spot-review-snapshot";

const STRENGTH_ORDER = { low: 0, medium: 1, high: 2, very_high: 3 };

function newAreas(current: string[], prior: string[]): string[] {
  const priorSet = new Set(prior.map((a) => a.toLowerCase()));
  return current.filter((a) => !priorSet.has(a.toLowerCase()));
}

export function buildBlindSpotReviewChanges(
  review: BlindSpotReviewResult,
  prior: BlindSpotReviewSnapshot | null,
): BlindSpotReviewChanges {
  const sectionTitle = BLIND_SPOT_PAGE.sinceLastTimeTitle;

  if (!prior) {
    return {
      hasPriorSnapshot: false,
      hasMeaningfulChange: false,
      sectionTitle,
      lines: [],
    };
  }

  const facts = review.evidenceStrengthFacts;
  const lines: BlindSpotReviewChangeLine[] = [];
  const newEntryIds = review.evidenceQuotes
    .map((q) => q.entryId)
    .filter((id) => !prior.entryIds.includes(id));

  const strengthUp =
    STRENGTH_ORDER[review.evidenceStrength] > STRENGTH_ORDER[prior.evidenceStrength];
  const priorMatchCount = prior.matchingReflectionCount ?? prior.entryIds.length;
  const morePatternReflections = facts.reflectionCount > priorMatchCount;
  const moreArchiveReflections =
    review.reflectionCount > (prior.archiveReflectionCount ?? priorMatchCount);
  const longerSpan = facts.spanDays > prior.spanDays + 7;
  const differentPattern = prior.reviewId !== review.reviewId;

  const sameReview = prior.reviewId === review.reviewId;
  const archiveGrew = moreArchiveReflections;

  if (
    strengthUp ||
    newEntryIds.length > 0 ||
    (sameReview && morePatternReflections) ||
    longerSpan ||
    (archiveGrew && differentPattern)
  ) {
    const parts: string[] = [];
    if (strengthUp) {
      parts.push(`evidence strength may have moved toward ${review.evidenceStrength.replace("_", " ")}`);
    }
    if (newEntryIds.length > 0) {
      parts.push(
        `${newEntryIds.length} new saved moment${newEntryIds.length === 1 ? "" : "s"} may support this`,
      );
    }
    if (archiveGrew && differentPattern) {
      parts.push("your archive has grown — a different thread may be surfacing");
    }
    if (archiveGrew && sameReview && newEntryIds.length > 0) {
      parts.push("new saved moments may be sharpening this thread");
    }
    if (longerSpan && parts.length === 0) {
      parts.push(`the time span may have widened (${facts.richSpanLabel})`);
    }
    lines.push({
      kind: "stronger_evidence",
      text: parts.join("; ") || "Supporting moments may have accumulated.",
    });
  }

  const addedAreas = newAreas(review.linkedAreas, prior.lifeAreas);
  if (addedAreas.length > 0) {
    lines.push({
      kind: "new_life_area",
      text: `This may now touch ${addedAreas.slice(0, 3).join(", ")} — not seen in the last review.`,
    });
  }

  if (facts.contradictionPresent && !prior.contradictionPresent) {
    lines.push({
      kind: "new_contradiction",
      text: "New contradiction signals may be present in your recent words.",
    });
  }

  if (facts.costEvidenceCount > prior.costEvidenceCount) {
    lines.push({
      kind: "new_cost_evidence",
      text: "Possible cost evidence may have strengthened since the last review.",
    });
  }

  const rootChanged =
    Boolean(review.rootBeliefHypothesis) &&
    Boolean(prior.rootBeliefHypothesis) &&
    review.rootBeliefHypothesis !== prior.rootBeliefHypothesis;
  if (rootChanged) {
    lines.push({
      kind: "changed_root_belief",
      text: "The underlying belief hypothesis may have shifted — still tentative.",
    });
  }

  const strengthDown =
    STRENGTH_ORDER[review.evidenceStrength] < STRENGTH_ORDER[prior.evidenceStrength];
  const contradictionSoftened = prior.contradictionPresent && !facts.contradictionPresent;
  if (strengthDown || contradictionSoftened) {
    lines.push({
      kind: "softened_resolved",
      text: strengthDown
        ? "This thread may be softening — or the archive may need more recent saved moments."
        : "Contradiction signals may have eased since the last review.",
    });
  }

  const hasMeaningfulChange = lines.length > 0;

  return {
    hasPriorSnapshot: true,
    hasMeaningfulChange,
    sectionTitle,
    noChangeMessage: hasMeaningfulChange ? undefined : BLIND_SPOT_PAGE.sinceLastTimeNoChange,
    lines,
  };
}
