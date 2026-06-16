import { saveBreakthroughEvent } from "@/lib/breakthrough/breakthrough-events";
import { offerInsightOutcomeAfterCommitment } from "@/lib/insights/insight-outcome-schedule";
import {
  readAllExperimentCommitments,
  writeExperimentCommitments,
} from "@/lib/blind-spots/blind-spot-experiment-commitment";
import type {
  BlindSpotExperimentCommitment,
  ExperimentCommitmentStatus,
  ExperimentFollowUpAnswer,
} from "@/types/blind-spot-experiment-loop";
import type { BreakthroughType } from "@/types/breakthrough-tracking";

function breakthroughForFollowUp(answer: ExperimentFollowUpAnswer): BreakthroughType | null {
  if (answer === "caught_earlier") return "caught_it_earlier";
  if (answer === "after_the_fact") return "noticed_pattern";
  return null;
}

function statusAfterFollowUp(answer: ExperimentFollowUpAnswer): ExperimentCommitmentStatus {
  if (answer === "no") return "not_tried";
  if (answer === "not_sure") return "pending";
  return "tried";
}

export function saveExperimentFollowUpAnswer(
  commitmentId: string,
  answer: ExperimentFollowUpAnswer,
): BlindSpotExperimentCommitment | null {
  const records = readAllExperimentCommitments();
  const index = records.findIndex((r) => r.commitmentId === commitmentId);
  if (index < 0) return null;

  const prior = records[index]!;
  const breakthroughType = breakthroughForFollowUp(answer);

  if (breakthroughType) {
    saveBreakthroughEvent({
      type: breakthroughType,
      answer: "yes",
      promptId: `blind_spot_experiment_followup_${answer}`,
      relatedBlindSpotId: prior.reviewId,
      attribution: {
        relatedBlindSpotId: prior.reviewId,
        insightProfile: prior.insightProfile,
      },
    });
  }

  records[index] = {
    ...prior,
    followUpAnswer: answer,
    followUpAnsweredAt: new Date().toISOString(),
    status: statusAfterFollowUp(answer),
  };
  writeExperimentCommitments(records);
  offerInsightOutcomeAfterCommitment(records[index]!);
  return records[index]!;
}
