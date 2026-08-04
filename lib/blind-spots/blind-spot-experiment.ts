import type { PatternInsight } from "@/lib/patterns/pattern-engine";
import type { EvidenceStrengthLabel, EvidenceStrengthFacts } from "@/types/blind-spot";
import type {
  BlindSpotExperiment,
  BlindSpotExperimentIngredient,
} from "@/types/blind-spot-experiment";

export const FORBIDDEN_EXPERIMENT_COPY =
  /\b(diagnos|disorder|patholog|clinical|trauma|therapy|counsel|coach|treatment|crisis|hotline|medication|prescrib|you should|you must|guaranteed|fix yourself|heal from)\b/i;

const CRITICISM_REJECTION_RE =
  /\b(reject|rejection|critic|judg|harsh feedback|they said|told me i|not good enough|worthless|failure)\b/i;

const SHOW_STRENGTH = new Set<EvidenceStrengthLabel>(["medium", "high", "very_high"]);
const MIN_SCORECARD_FOR_EXPERIMENT = 40;

export function shouldShowBlindSpotExperiment(input: {
  evidenceStrength: EvidenceStrengthLabel;
  scorecardScore?: number;
}): boolean {
  if (SHOW_STRENGTH.has(input.evidenceStrength)) return true;
  return (input.scorecardScore ?? 0) >= MIN_SCORECARD_FOR_EXPERIMENT;
}

export interface BlindSpotExperimentInput {
  insight: PatternInsight;
  signalIds: string[];
  evidenceStrengthFacts: EvidenceStrengthFacts;
  failedPredictionLinked: boolean;
  evidenceStrength: EvidenceStrengthLabel;
  scorecardScore?: number;
}

export function buildBlindSpotExperiment(
  input: BlindSpotExperimentInput,
): BlindSpotExperiment | null {
  if (
    !shouldShowBlindSpotExperiment({
      evidenceStrength: input.evidenceStrength,
      scorecardScore: input.scorecardScore,
    })
  ) {
    return null;
  }

  const ingredient = pickExperimentIngredient(input);
  const experiment = experimentForIngredient(ingredient);
  if (!experiment || !passesExperimentCopyGate(experiment)) return null;
  return experiment;
}

function pickExperimentIngredient(
  input: BlindSpotExperimentInput,
): BlindSpotExperimentIngredient {
  const blob = [input.insight.title, input.insight.detail].join(" ");
  const { signalIds } = input;
  const facts = input.evidenceStrengthFacts;

  if (
    input.failedPredictionLinked ||
    signalIds.includes("wrong_prediction") ||
    facts.failedPredictionCount > 0
  ) {
    return "prediction_failure";
  }

  if (
    signalIds.includes("self_worth_collapse") ||
    CRITICISM_REJECTION_RE.test(blob)
  ) {
    return "criticism_rejection";
  }

  if (
    signalIds.includes("avoidance") ||
    signalIds.includes("delayed_decision") ||
    input.insight.type === "avoidance_signal"
  ) {
    return "avoidance_delay";
  }

  if (signalIds.includes("conflict") || signalIds.includes("emotional_spiral")) {
    return "conflict_spiral";
  }

  if (facts.lifeAreaCount >= 2) {
    return "cross_life_area";
  }

  return "avoidance_delay";
}

function experimentForIngredient(
  ingredient: BlindSpotExperimentIngredient,
): BlindSpotExperiment {
  switch (ingredient) {
    case "criticism_rejection":
      return {
        ingredient,
        smallThing:
          "Before you decide what feedback means about you, wait 24 hours — then write one sentence about what was said, separate from what you feared it proved.",
        tryNextTime:
          "Try this next time words land hard: note the exact phrase first, then pause before the story about you forms.",
        checkWhether:
          "Check whether your read of the comment shifts after a day — without forcing a verdict.",
      };
    case "prediction_failure":
      return {
        ingredient,
        smallThing:
          "Write the prediction in one sentence before the week unfolds; later, add what actually happened beside it — same page, two columns.",
        tryNextTime:
          "Try this next time you feel sure something will go wrong: date the prediction, then let later saved moments answer it.",
        checkWhether:
          "Check whether the outcome matched the fear, or only matched the mood you were in when you wrote it.",
      };
    case "avoidance_delay":
      return {
        ingredient,
        smallThing:
          "Name the avoided decision in one sentence — not a plan yet, just the fork you keep circling.",
        tryNextTime:
          "Try this next time you feel the stall: say the decision out loud once, then stop — no solving step required.",
        checkWhether:
          "Check whether naming the fork makes the delay feel smaller, or only clearer.",
      };
    case "conflict_spiral":
      return {
        ingredient,
        smallThing:
          "On one line, write what happened; on the next, what you assumed it meant — keep them separate for one situation.",
        tryNextTime:
          "Try this next time tension spikes: facts first, interpretation second — still tentative.",
        checkWhether:
          "Check whether the assumption and the event still feel glued together, or start to separate.",
      };
    case "cross_life_area":
      return {
        ingredient,
        smallThing:
          "This week, notice whether the same reaction shows up in another area you care about — same feeling, different setting.",
        tryNextTime:
          "Try this next time the pattern fires: tag which life area you are in, then ask if it rhymes elsewhere.",
        checkWhether:
          "Check whether the thread is truly cross-area, or only loud in one place right now.",
      };
  }
}

export function passesExperimentCopyGate(experiment: BlindSpotExperiment): boolean {
  const blob = [experiment.smallThing, experiment.tryNextTime, experiment.checkWhether].join(
    " ",
  );
  return !FORBIDDEN_EXPERIMENT_COPY.test(blob);
}
