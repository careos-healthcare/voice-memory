import {
  buildResurfacingScores,
  mapThreadTypeToReason,
  shouldShowResurfacing,
  whySurfacedLine,
} from "@/lib/resurfacing/resurfacing-scoring";
import {
  EMOTIONAL_EVAL_DATASET,
  type EmotionalEvalCase,
} from "@/lib/emotional-quality/eval-dataset";
import { isGenericResurfacing } from "@/lib/resurfacing/genericity-filter";
import { recordResurfacingFeedback } from "@/lib/resurfacing/resurfacing-feedback";

export interface EmotionalQualityMetrics {
  cases: number;
  precisionProxy: number;
  quoteBackedRate: number;
  genericPhraseRate: number;
  repeatSuppressionRate: number;
  notMePenaltyEffective: boolean;
  ambiguityPresent: boolean;
}

const THRESHOLDS = {
  minPrecisionProxy: 0.6,
  maxGenericRate: 0.35,
  minQuoteBackedRate: 0.5,
};

function seedFeedback(case_: EmotionalEvalCase): void {
  if (!case_.priorFeedback) return;
  recordResurfacingFeedback({
    kind: case_.priorFeedback,
    quote: case_.quote,
    surface: "first_return",
  });
}

export function runEmotionalQualityEval(): {
  metrics: EmotionalQualityMetrics;
  failures: string[];
  ok: boolean;
} {
  const failures: string[] = [];
  let correct = 0;
  let quoteBackedShown = 0;
  let shown = 0;
  let genericFalsePositives = 0;
  let genericCases = 0;
  let repeatBlocked = 0;
  let notMeCaseOk = true;
  let ambiguityPresent = true;

  for (const case_ of EMOTIONAL_EVAL_DATASET) {
    if (case_.priorFeedback) seedFeedback(case_);

    const scores = buildResurfacingScores({
      quote: case_.quote,
      appearances: case_.appearances,
      gapDays: case_.gapDays,
      threadType: case_.threadType,
    });
    const show = shouldShowResurfacing(scores, case_.quote);
    const generic = isGenericResurfacing(case_.quote);
    const reason = mapThreadTypeToReason(case_.threadType ?? "repeated_phrase");
    const uncertain = scores.finalResurfacingConfidence < 68;
    const why = whySurfacedLine(reason, uncertain);

    if (show === case_.expectShow) correct += 1;
    else {
      failures.push(
        `${case_.id}: expected show=${case_.expectShow} got ${show} (confidence=${scores.finalResurfacingConfidence})`,
      );
    }

    if (case_.expectGeneric) {
      genericCases += 1;
      if (show) genericFalsePositives += 1;
    }

    if (show) {
      shown += 1;
      if (case_.expectQuoteBacked && scores.quoteMatchScore >= 50) quoteBackedShown += 1;
    }

    if (case_.id === "not-me-penalized" && show) {
      notMeCaseOk = false;
      failures.push("not-me-penalized: resurfacing still shown after not_me feedback");
    }

    if (case_.appearances >= 2 && !show && !case_.expectShow) {
      repeatBlocked += 1;
    }

    if (uncertain && !why.toLowerCase().includes("might")) {
      ambiguityPresent = false;
      failures.push(`${case_.id}: low confidence missing ambiguity phrasing`);
    }
  }

  const metrics: EmotionalQualityMetrics = {
    cases: EMOTIONAL_EVAL_DATASET.length,
    precisionProxy: correct / EMOTIONAL_EVAL_DATASET.length,
    quoteBackedRate: shown > 0 ? quoteBackedShown / shown : 0,
    genericPhraseRate: genericCases > 0 ? genericFalsePositives / genericCases : 0,
    repeatSuppressionRate: repeatBlocked / EMOTIONAL_EVAL_DATASET.length,
    notMePenaltyEffective: notMeCaseOk,
    ambiguityPresent,
  };

  if (metrics.precisionProxy < THRESHOLDS.minPrecisionProxy) {
    failures.push(
      `precision proxy ${metrics.precisionProxy.toFixed(2)} < ${THRESHOLDS.minPrecisionProxy}`,
    );
  }
  if (metrics.genericPhraseRate > THRESHOLDS.maxGenericRate) {
    failures.push(
      `generic rate ${metrics.genericPhraseRate.toFixed(2)} > ${THRESHOLDS.maxGenericRate}`,
    );
  }
  if (shown > 0 && metrics.quoteBackedRate < THRESHOLDS.minQuoteBackedRate) {
    failures.push(
      `quote-backed rate ${metrics.quoteBackedRate.toFixed(2)} < ${THRESHOLDS.minQuoteBackedRate}`,
    );
  }
  if (!metrics.notMePenaltyEffective) {
    failures.push("not-me penalty did not suppress resurfacing");
  }
  if (!metrics.ambiguityPresent) {
    failures.push("ambiguity handling missing on low-confidence cases");
  }

  return { metrics, failures, ok: failures.length === 0 };
}
