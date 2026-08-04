import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { formatEntryDate } from "@/lib/utils";
import type { PredictionCandidate } from "@/types/blind-spot-acceleration";
import type {
  PredictionAccuracySummary,
  PredictionLaterEvidence,
  PredictionOutcomeStatus,
  PredictionReviewItem,
  PredictionReviewReport,
} from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

const LATER_WINDOW_DAYS = 90;

const POSITIVE_REVERSAL =
  /\b(better|relieved|worked|fine|okay|ok|wasn'?t as bad|didn'?t happen|went well|surprised|easier|more positive)\b/i;
const NEGATIVE_REVERSAL =
  /\b(worse|harder|failed|fell apart|did happen|as bad as|right about|confirmed)\b/i;
const FAILURE_PREDICTION = /\b(fail|failure|mess up|fall apart|go wrong)\b/i;

function trimQuote(text: string): string {
  const n = text.replace(/\s+/g, " ").trim();
  return n.length <= 200 ? n : `${n.slice(0, 197)}…`;
}

function findLaterEvidence(
  candidate: PredictionCandidate,
  entries: JournalEntry[],
): PredictionLaterEvidence | undefined {
  const predKey = toDayKey(candidate.predictedAt);
  const later = entries
    .filter((e) => e.reflectionPending !== true && e.id !== candidate.entryId)
    .filter((e) => toDayKey(e.createdAt) > predKey)
    .filter((e) => daysBetweenKeys(predKey, toDayKey(e.createdAt)) <= LATER_WINDOW_DAYS)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

  const hit = later[0];
  if (!hit) return undefined;

  const quote =
    hit.reflection.concreteObservation?.trim() ||
    hit.reflection.exactLanguagePattern?.trim() ||
    hit.transcript.trim().slice(0, 180);

  if (!quote) return undefined;

  return {
    entryId: hit.id,
    dateLabel: formatEntryDate(hit.createdAt),
    quote: trimQuote(quote),
  };
}

function classifyOutcome(
  candidate: PredictionCandidate,
  later?: PredictionLaterEvidence,
): { status: PredictionOutcomeStatus; summary: string } {
  if (!later) {
    return {
      status: "pending",
      summary: "This may still be open — no later saved moment in range to compare yet.",
    };
  }

  const laterText = later.quote;
  const isFailurePred = FAILURE_PREDICTION.test(candidate.quote);

  if (candidate.polarity === "negative") {
    if (POSITIVE_REVERSAL.test(laterText)) {
      return {
        status: "diverged",
        summary:
          "Your later words suggest this may not have unfolded as negatively as you expected.",
      };
    }
    if (NEGATIVE_REVERSAL.test(laterText)) {
      return {
        status: "aligned",
        summary: "Your later words may line up with the concern you named — not proof, just echo.",
      };
    }
  }

  if (candidate.polarity === "positive") {
    if (NEGATIVE_REVERSAL.test(laterText)) {
      return {
        status: "diverged",
        summary: "Your later words suggest this may not have gone as well as you hoped.",
      };
    }
    if (POSITIVE_REVERSAL.test(laterText)) {
      return {
        status: "aligned",
        summary: "Your later words may line up with what you expected — still only one thread.",
      };
    }
  }

  if (isFailurePred && POSITIVE_REVERSAL.test(laterText)) {
    return {
      status: "diverged",
      summary:
        "Your later words suggest the outcome may have been more positive than this failure prediction.",
    };
  }

  return {
    status: "unclear",
    summary: "This may or may not have diverged — the later saved moment does not name it clearly.",
  };
}

export function buildPredictionReview(
  candidates: PredictionCandidate[],
  entries: JournalEntry[],
): PredictionReviewReport {
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  const items: PredictionReviewItem[] = candidates.slice(0, 12).map((candidate) => {
    const laterEvidence = findLaterEvidence(candidate, eligible);
    const { status, summary } = classifyOutcome(candidate, laterEvidence);
    return {
      candidate,
      laterEvidence,
      outcomeStatus: status,
      outcomeSummary: summary,
    };
  });

  const accuracy = buildPredictionAccuracySummary(items);

  return {
    items,
    accuracy,
    hasData: items.length > 0,
  };
}

export function buildPredictionAccuracySummary(
  items: PredictionReviewItem[],
): PredictionAccuracySummary {
  const withLater = items.filter((i) => i.laterEvidence);
  const negativeItems = withLater.filter((i) => i.candidate.polarity === "negative");
  const negativeDidNotHappen = negativeItems.filter((i) => i.outcomeStatus === "diverged").length;

  const failureItems = withLater.filter((i) => FAILURE_PREDICTION.test(i.candidate.quote));
  const failureMorePositive = failureItems.filter((i) => i.outcomeStatus === "diverged").length;

  const summaryLines: string[] = [];

  if (negativeItems.length > 0) {
    summaryLines.push(
      `You made ${negativeItems.length} negative prediction${negativeItems.length === 1 ? "" : "s"}.`,
    );
    if (negativeDidNotHappen > 0) {
      summaryLines.push(
        `${negativeDidNotHappen} may not have happened the way you expected — based on later saved moments, not certainty.`,
      );
    }
  }

  if (failureItems.length > 0) {
    summaryLines.push(
      `You predicted failure ${failureItems.length} time${failureItems.length === 1 ? "" : "s"}.`,
    );
    if (failureMorePositive > 0) {
      summaryLines.push(
        `${failureMorePositive} outcome${failureMorePositive === 1 ? "" : "s"} may have been more positive than expected — your words, compared across dates.`,
      );
    }
  }

  if (summaryLines.length === 0 && withLater.length > 0) {
    summaryLines.push(
      `${withLater.length} prediction${withLater.length === 1 ? "" : "s"} with later saved moments — outcomes still mixed or unclear.`,
    );
  }

  return {
    totalPredictions: withLater.length,
    negativePredictions: negativeItems.length,
    negativeDidNotHappen,
    failurePredictions: failureItems.length,
    failureMorePositiveThanExpected: failureMorePositive,
    summaryLines,
  };
}
