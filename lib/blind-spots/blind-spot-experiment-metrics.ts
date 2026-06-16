import { readAllExperimentCommitments } from "@/lib/blind-spots/blind-spot-experiment-commitment";
import { readAllBlindSpotExperimentFeedback } from "@/lib/blind-spots/blind-spot-experiment-feedback";
import type {
  BlindSpotExperimentLoopReport,
  ExperimentIngredientMetricRow,
  ExperimentMetricIngredient,
} from "@/types/blind-spot-experiment-loop";

const INGREDIENT_LABELS: Record<ExperimentMetricIngredient, string> = {
  contradiction: "Contradiction",
  cost_evidence: "Cost evidence",
  cross_life_area: "Cross life area",
  failed_prediction: "Failed prediction",
  long_span: "Long span",
};

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

export function buildBlindSpotExperimentLoopReport(): BlindSpotExperimentLoopReport {
  const commitments = readAllExperimentCommitments();
  const feedback = readAllBlindSpotExperimentFeedback();

  const eligibleSurfaces = feedback.length;
  const commitmentCount = commitments.filter(
    (c) => c.status === "pending" || c.status === "tried",
  ).length;
  const followUpCompleted = commitments.filter((c) => c.followUpAnswer);
  const caughtEarlier = followUpCompleted.filter(
    (c) => c.followUpAnswer === "caught_earlier",
  );
  const duePending = commitments.filter(
    (c) => c.status === "pending" && !c.followUpAnswer,
  );

  const byIngredient: ExperimentIngredientMetricRow[] = (
    Object.keys(INGREDIENT_LABELS) as ExperimentMetricIngredient[]
  ).map((ingredient) => {
    const tagged = commitments.filter((c) => c.metricIngredients.includes(ingredient));
    const completed = tagged.filter((c) => c.followUpAnswer);
    const caught = completed.filter((c) => c.followUpAnswer === "caught_earlier");
    return {
      ingredient,
      label: INGREDIENT_LABELS[ingredient],
      commitments: tagged.length,
      followUpsCompleted: completed.length,
      caughtEarlier: caught.length,
      caughtEarlierRate: pct(caught.length, completed.length),
    };
  });

  const commitmentRate = pct(commitmentCount, Math.max(eligibleSurfaces, commitmentCount));
  const followUpCompletionRate = pct(
    followUpCompleted.length,
    Math.max(commitmentCount, followUpCompleted.length),
  );
  const caughtEarlierRate = pct(
    caughtEarlier.length,
    Math.max(followUpCompleted.length, caughtEarlier.length),
  );

  const lines = [
    `Experiment commitments: ${commitmentCount} (${commitmentRate ?? "—"}% of feedback touches)`,
    `Follow-ups completed: ${followUpCompleted.length} (${followUpCompletionRate ?? "—"}%)`,
    `Caught it earlier: ${caughtEarlier.length} (${caughtEarlierRate ?? "—"}% of completed follow-ups)`,
    `Due now: ${duePending.filter((c) => new Date(c.dueAt).getTime() <= Date.now()).length}`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    eligibleExperimentSurfaces: eligibleSurfaces,
    commitmentCount,
    commitmentRate,
    dueFollowUpCount: duePending.length,
    followUpCompletedCount: followUpCompleted.length,
    followUpCompletionRate,
    caughtEarlierCount: caughtEarlier.length,
    caughtEarlierRate,
    byIngredient,
    lines,
  };
}
