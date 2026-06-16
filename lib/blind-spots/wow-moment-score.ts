import type { BlindSpotReaction } from "@/types/blind-spot";

const WOW_WEIGHTS: Record<BlindSpotReaction, number> = {
  surprising: 2,
  uncomfortably_accurate: 3,
  interesting: 1,
  obvious: -1,
  completely_wrong: -3,
};

export function wowMomentScoreForReaction(reaction: BlindSpotReaction): number {
  return WOW_WEIGHTS[reaction];
}

export function sumWowMomentScore(reactions: BlindSpotReaction[]): number {
  return reactions.reduce((sum, r) => sum + wowMomentScoreForReaction(r), 0);
}

export function averageWowMomentScore(reactions: BlindSpotReaction[]): number {
  if (reactions.length === 0) return 0;
  return Math.round((sumWowMomentScore(reactions) / reactions.length) * 100) / 100;
}
