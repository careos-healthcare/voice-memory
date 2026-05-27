import {
  getAnticipatoryEmptyCopy,
  getEntryTier,
  type EntryTier,
} from "@/lib/product/anticipatory-memory-copy";
import { WEDGE_RESURFACING } from "@/lib/product-copy";

export type { EntryTier } from "@/lib/product/anticipatory-memory-copy";
export { getEntryTier } from "@/lib/product/anticipatory-memory-copy";

export interface EmptyStateMessage {
  tier: EntryTier;
  headline: string;
  body: string;
  hint?: string;
}

export function getEmptyStateMessage(entryCount: number): EmptyStateMessage {
  const anticipatory = getAnticipatoryEmptyCopy(entryCount);
  const tier = anticipatory.tier;
  if (tier === "one") {
    return {
      tier,
      headline: anticipatory.headline,
      body: anticipatory.body,
      hint: "Record again when the same concern or phrase comes back.",
    };
  }
  if (tier === "rich") {
    return {
      tier,
      headline: anticipatory.headline,
      body: `${WEDGE_RESURFACING.forgottenPatterns} ${WEDGE_RESURFACING.ownVoicePattern}`,
    };
  }
  return {
    tier,
    headline: anticipatory.headline,
    body: anticipatory.body,
  };
}

export function getTierProgressLabel(entryCount: number): string {
  const tier = getEntryTier(entryCount);
  switch (tier) {
    case "none":
      return "0 reflections";
    case "one":
      return "1 reflection";
    case "few":
      return `${entryCount} reflections`;
    case "building":
      return `${entryCount} reflections`;
    case "rich":
      return `${entryCount} reflections`;
  }
}
