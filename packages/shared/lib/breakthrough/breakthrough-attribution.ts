import { readDiscoverLastVisitAt } from "@/lib/discover/discover-visit";
import { readNotificationLifecycleRecords } from "@/lib/theories/theory-notification-lifecycle";
import { readAllTheoryEvents, THEORY_EVENTS } from "@/lib/theories/theory-events";
import {
  lifeAreaCountForQuotes,
  spanDaysForQuotes,
} from "@/lib/theories/theory-confidence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type {
  BreakthroughAttribution,
  BreakthroughInsightProfile,
} from "@/types/breakthrough-tracking";
import type { Theory } from "@/types/theory";

const LONG_SPAN_DAYS = 30;

export function insightProfileFromBlindSpotReview(
  review: BlindSpotReviewResult,
): BreakthroughInsightProfile {
  const facts = review.evidenceStrengthFacts;
  return {
    hasContradiction: facts.contradictionPresent || Boolean(review.contradictionNote),
    hasPredictionFailure: facts.failedPredictionCount > 0 || Boolean(review.predictionEvidenceNote),
    hasCostEvidence: facts.costEvidenceCount > 0 || review.costEvidenceLines.length > 0,
    hasCrossLifeArea: facts.lifeAreaCount >= 2 || review.linkedAreas.length >= 2,
    hasLongTimeSpan: facts.spanDays >= LONG_SPAN_DAYS,
  };
}

export function insightProfileFromTheory(theory: Theory): BreakthroughInsightProfile {
  const entries = getMemoryEligibleEntries();
  const entriesById = new Map(entries.map((e) => [e.id, e]));
  const allQuotes = [...theory.supportingEvidence, ...theory.contradictingEvidence];
  const spanDays = spanDaysForQuotes(allQuotes, entriesById);
  const lifeAreaCount = lifeAreaCountForQuotes(allQuotes, entries);

  return {
    hasContradiction: theory.contradictingEvidence.length > 0,
    hasPredictionFailure: theory.source === "prediction",
    hasCostEvidence: theory.whatChanged.some((line) => /cost|expensive|price/i.test(line)),
    hasCrossLifeArea: lifeAreaCount >= 2,
    hasLongTimeSpan: spanDays >= LONG_SPAN_DAYS,
  };
}

function lastDiscoverVisitAt(): string | undefined {
  const events = readAllTheoryEvents()
    .filter((e) => e.name === THEORY_EVENTS.discoverOpened)
    .sort((a, b) => b.at.localeCompare(a.at));
  if (events[0]?.at) return events[0].at;

  return readDiscoverLastVisitAt() ?? undefined;
}

function lastOpenedNotification(theoryId?: string): {
  notificationId?: string;
  notificationType?: BreakthroughAttribution["relatedNotificationType"];
} {
  const records = readNotificationLifecycleRecords().filter((r) => r.openedAt);
  const sorted = [...records].sort((a, b) =>
    (b.openedAt ?? "").localeCompare(a.openedAt ?? ""),
  );
  const match = theoryId
    ? sorted.find((r) => r.theoryId === theoryId)
    : sorted[0];
  if (!match) return {};
  return {
    notificationId: match.notificationId,
    notificationType: match.type,
  };
}

export function buildBlindSpotAttribution(
  review: BlindSpotReviewResult,
): BreakthroughAttribution {
  const notification = lastOpenedNotification();
  return {
    relatedBlindSpotId: review.reviewId,
    relatedNotificationId: notification.notificationId,
    relatedNotificationType: notification.notificationType,
    lastDiscoverVisitAt: lastDiscoverVisitAt(),
    insightProfile: insightProfileFromBlindSpotReview(review),
  };
}

export function buildTheoryAttribution(theory: Theory): BreakthroughAttribution {
  const notification = lastOpenedNotification(theory.id);
  return {
    relatedTheoryId: theory.id,
    relatedNotificationId: notification.notificationId,
    relatedNotificationType: notification.notificationType,
    lastDiscoverVisitAt: lastDiscoverVisitAt(),
    insightProfile: insightProfileFromTheory(theory),
  };
}
