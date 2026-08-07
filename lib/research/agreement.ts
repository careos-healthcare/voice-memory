import {
  RESEARCH_FEEDBACK_CATEGORIES,
  type ResearchFeedbackCategory,
} from "./research-domain";

export type CategoryDecision = Partial<
  Record<ResearchFeedbackCategory, boolean>
>;

export interface AgreementMetric {
  score: number | null;
  observedAgreement: number | null;
  expectedAgreement: number | null;
  sampleSize: number;
  status:
    | "measured"
    | "perfect"
    | "zero_variance_agreement"
    | "insufficient_data";
}

export interface AgreementSummary {
  method: "cohen" | "fleiss_compatible";
  reviewerCount: number;
  perCategory: Record<ResearchFeedbackCategory, AgreementMetric>;
  aggregate: AgreementMetric;
}

function metric(
  observedAgreement: number,
  expectedAgreement: number,
  sampleSize: number,
): AgreementMetric {
  if (sampleSize === 0) {
    return {
      score: null,
      observedAgreement: null,
      expectedAgreement: null,
      sampleSize: 0,
      status: "insufficient_data",
    };
  }
  if (expectedAgreement === 1) {
    return {
      score: observedAgreement === 1 ? 1 : 0,
      observedAgreement,
      expectedAgreement,
      sampleSize,
      status:
        observedAgreement === 1 ? "zero_variance_agreement" : "measured",
    };
  }
  const score = (observedAgreement - expectedAgreement) /
    (1 - expectedAgreement);
  return {
    score,
    observedAgreement,
    expectedAgreement,
    sampleSize,
    status:
      observedAgreement === 1 && score === 1 ? "perfect" : "measured",
  };
}

export function cohenKappa(
  pairs: readonly (readonly [boolean | undefined, boolean | undefined])[],
): AgreementMetric {
  const complete = pairs.filter(
    (pair): pair is readonly [boolean, boolean] =>
      pair[0] !== undefined && pair[1] !== undefined,
  );
  if (complete.length === 0) return metric(0, 0, 0);

  const observed =
    complete.filter(([left, right]) => left === right).length / complete.length;
  const leftTrue = complete.filter(([left]) => left).length / complete.length;
  const rightTrue =
    complete.filter(([, right]) => right).length / complete.length;
  const expected =
    leftTrue * rightTrue + (1 - leftTrue) * (1 - rightTrue);
  return metric(observed, expected, complete.length);
}

export function fleissKappa(
  subjects: readonly (readonly (boolean | undefined)[])[],
): AgreementMetric {
  const complete = subjects
    .map((ratings) =>
      ratings.filter((rating): rating is boolean => rating !== undefined),
    )
    .filter((ratings) => ratings.length >= 2);
  if (complete.length === 0) return metric(0, 0, 0);

  const observed =
    complete.reduce((sum, ratings) => {
      const yes = ratings.filter(Boolean).length;
      const no = ratings.length - yes;
      return sum + (yes * (yes - 1) + no * (no - 1)) /
        (ratings.length * (ratings.length - 1));
    }, 0) / complete.length;
  const allRatings = complete.flat();
  const yesShare = allRatings.filter(Boolean).length / allRatings.length;
  const expected = yesShare ** 2 + (1 - yesShare) ** 2;
  return metric(observed, expected, complete.length);
}

function decisionsForCategory(
  records: readonly (readonly CategoryDecision[])[],
  category: ResearchFeedbackCategory,
): readonly (readonly (boolean | undefined)[])[] {
  return records.map((reviewers) =>
    reviewers.map((labels) => labels[category]),
  );
}

export function summarizeAgreement(
  records: readonly (readonly CategoryDecision[])[],
): AgreementSummary {
  const reviewerCount = records.reduce(
    (maximum, record) => Math.max(maximum, record.length),
    0,
  );
  const useCohen =
    reviewerCount <= 2 && records.every((record) => record.length === 2);
  const calculate = (
    subjects: readonly (readonly (boolean | undefined)[])[],
  ) =>
    useCohen
      ? cohenKappa(
          subjects.map((ratings) => [ratings[0], ratings[1]] as const),
        )
      : fleissKappa(subjects);

  const perCategory = Object.fromEntries(
    RESEARCH_FEEDBACK_CATEGORIES.map((category) => [
      category,
      calculate(decisionsForCategory(records, category)),
    ]),
  ) as Record<ResearchFeedbackCategory, AgreementMetric>;

  const aggregateSubjects = records.flatMap((reviewers) =>
    RESEARCH_FEEDBACK_CATEGORIES.map((category) =>
      reviewers.map((labels) => labels[category]),
    ),
  );

  return {
    method: useCohen ? "cohen" : "fleiss_compatible",
    reviewerCount,
    perCategory,
    aggregate: calculate(aggregateSubjects),
  };
}
