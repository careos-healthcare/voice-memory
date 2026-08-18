import { THEORY_MOVEMENT_COPY } from "@/lib/discover/theory-movement-copy";
import type { TheoryMovementFeedReport, TheoryMovementItem, TheoryMovementKind } from "@/types/theory-curiosity-engine";
import type {
  TheoryChangeFeedReport,
  TheoryChangeItem,
  TheoryResolutionFeedReport,
  Theory,
} from "@/types/theory";

function lifeAreaHintFromText(text: string): string | undefined {
  if (/\b(work|job|career|manager|office)\b/i.test(text)) return "work";
  if (/\b(partner|relationship|friend|dating|marriage)\b/i.test(text)) return "relationships";
  if (/\b(money|pay|bill|debt|afford)\b/i.test(text)) return "money";
  if (/\b(family|parent|mom|dad|sibling)\b/i.test(text)) return "family";
  if (/\b(health|sleep|anxious|stress)\b/i.test(text)) return "health";
  return undefined;
}

function whyForIncreased(item: TheoryChangeItem): string {
  const area = lifeAreaHintFromText(item.statement);
  if (area) return THEORY_MOVEMENT_COPY.supportingWhyArea(area);
  if (item.shortReason && !/^Confidence/i.test(item.shortReason)) {
    return item.shortReason;
  }
  return THEORY_MOVEMENT_COPY.supportingWhy;
}

function whyForDecreased(item: TheoryChangeItem): string {
  if (item.contradictingEvidenceCount > 0) {
    return THEORY_MOVEMENT_COPY.contradictingWhy;
  }
  if (item.shortReason && !/^Confidence/i.test(item.shortReason)) {
    return item.shortReason;
  }
  return THEORY_MOVEMENT_COPY.contradictingWhy;
}

function movementFromChange(
  item: TheoryChangeItem,
  kind: "confidence_increased" | "confidence_decreased",
): TheoryMovementItem {
  const from = item.confidence - item.confidenceDelta;
  const to = item.confidence;
  const headline =
    kind === "confidence_increased"
      ? `${THEORY_MOVEMENT_COPY.confidenceIncreased} from ${from}% → ${to}%`
      : `${THEORY_MOVEMENT_COPY.confidenceDecreased} from ${from}% → ${to}%`;

  return {
    id: `${kind}-${item.theoryId}`,
    theoryId: item.theoryId,
    kind,
    headline,
    why: kind === "confidence_increased" ? whyForIncreased(item) : whyForDecreased(item),
    fromConfidence: from,
    toConfidence: to,
    updatedAt: item.updatedAt,
  };
}

function movementFromRetired(theory: Theory): TheoryMovementItem {
  return {
    id: `retired-${theory.id}`,
    theoryId: theory.id,
    kind: "theory_retired",
    headline: THEORY_MOVEMENT_COPY.theoryRetired,
    why: THEORY_MOVEMENT_COPY.retiredWhy,
    toConfidence: theory.confidence,
    updatedAt: theory.updatedAt,
  };
}

/** Human-readable movement lines for Discover — curiosity without gamification. */
export function buildTheoryMovementFeed(
  changeFeed: TheoryChangeFeedReport,
  resolutionFeed: TheoryResolutionFeedReport,
): TheoryMovementFeedReport {
  if (!changeFeed.hasBaseline) {
    return {
      generatedAt: new Date().toISOString(),
      hasBaseline: false,
      movements: [],
      totalMovements: 0,
    };
  }

  const movements: TheoryMovementItem[] = [];

  for (const item of changeFeed.strengthened) {
    movements.push(movementFromChange(item, "confidence_increased"));
  }
  for (const item of changeFeed.weakened) {
    movements.push(movementFromChange(item, "confidence_decreased"));
  }

  for (const theory of resolutionFeed.retired) {
    movements.push(movementFromRetired(theory));
  }

  for (const item of changeFeed.resolved) {
    if (item.status === "retired" || item.category === "resolved") {
      movements.push({
        id: `resolved-${item.theoryId}`,
        theoryId: item.theoryId,
        kind: "theory_retired",
        headline: THEORY_MOVEMENT_COPY.theoryRetired,
        why: THEORY_MOVEMENT_COPY.retiredWhy,
        fromConfidence: item.confidence - item.confidenceDelta,
        toConfidence: item.confidence,
        updatedAt: item.updatedAt,
      });
    }
  }

  const seen = new Set<string>();
  const deduped = movements.filter((m) => {
    if (seen.has(m.theoryId)) return false;
    seen.add(m.theoryId);
    return true;
  });

  const kindOrder: Record<TheoryMovementKind, number> = {
    confidence_increased: 0,
    confidence_decreased: 1,
    theory_retired: 2,
  };

  deduped.sort((a, b) => {
    const order = kindOrder[a.kind] - kindOrder[b.kind];
    if (order !== 0) return order;
    return Math.abs((b.toConfidence ?? 0) - (b.fromConfidence ?? 0)) -
      Math.abs((a.toConfidence ?? 0) - (a.fromConfidence ?? 0));
  });

  return {
    generatedAt: new Date().toISOString(),
    hasBaseline: true,
    movements: deduped,
    totalMovements: deduped.length,
  };
}
