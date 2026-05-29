import type { ResurfacingFeedbackKind } from "@/lib/resurfacing/resurfacing-feedback";

/** Merged local + server feedback for scoring — keys are client phrase/topic/person keys. */
export interface ResurfacingFeedbackSummary {
  phrasePenalties: Record<string, number>;
  topicPenalties: Record<string, number>;
  personPenalties: Record<string, number>;
  acceptanceBoosts: Record<string, number>;
  specificityThresholdBoost: number;
  intensityCautious: boolean;
  clusterRetired: Record<string, boolean>;
  clusterCooldownUntil: Record<string, string>;
  source: "local" | "merged";
}

export const FEEDBACK_WEIGHT_BY_KIND: Record<ResurfacingFeedbackKind, number> = {
  not_me: 35,
  missed: 12,
  dismissed: 8,
  that_fits: -12,
  wrong_topic: 28,
  wrong_person: 30,
  too_intense: 10,
  too_vague: 8,
  already_know: 22,
  show_less: 18,
};

export const SERVER_FEEDBACK_ALLOWLIST: ResurfacingFeedbackKind[] = [
  "not_me",
  "missed",
  "dismissed",
  "that_fits",
  "wrong_topic",
  "wrong_person",
  "too_intense",
  "too_vague",
  "already_know",
  "show_less",
];

export function emptyFeedbackSummary(): ResurfacingFeedbackSummary {
  return {
    phrasePenalties: {},
    topicPenalties: {},
    personPenalties: {},
    acceptanceBoosts: {},
    specificityThresholdBoost: 0,
    intensityCautious: false,
    clusterRetired: {},
    clusterCooldownUntil: {},
    source: "local",
  };
}

export function mergeFeedbackSummaries(
  local: ResurfacingFeedbackSummary,
  server: ResurfacingFeedbackSummary | null,
): ResurfacingFeedbackSummary {
  if (!server) return { ...local, source: "local" };

  const mergeNum = (a: Record<string, number>, b: Record<string, number>) => {
    const out = { ...a };
    for (const [k, v] of Object.entries(b)) {
      out[k] = Math.max(out[k] ?? 0, v);
    }
    return out;
  };

  return {
    phrasePenalties: mergeNum(local.phrasePenalties, server.phrasePenalties),
    topicPenalties: mergeNum(local.topicPenalties, server.topicPenalties),
    personPenalties: mergeNum(local.personPenalties, server.personPenalties),
    acceptanceBoosts: mergeNum(local.acceptanceBoosts, server.acceptanceBoosts),
    specificityThresholdBoost: Math.max(
      local.specificityThresholdBoost,
      server.specificityThresholdBoost,
    ),
    intensityCautious: local.intensityCautious || server.intensityCautious,
    clusterRetired: { ...local.clusterRetired, ...server.clusterRetired },
    clusterCooldownUntil: {
      ...local.clusterCooldownUntil,
      ...server.clusterCooldownUntil,
    },
    source: "merged",
  };
}
