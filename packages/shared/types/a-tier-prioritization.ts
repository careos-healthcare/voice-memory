import type { InsightIngredientTier } from "@/types/insight-ingredient-optimizer";

/** User-visible evidence quality — never includes raw optimizer score. */
export type PublicEvidenceQualityTier = "a_tier" | "b_tier" | "c_tier";

export interface ATierTierRateRow {
  tier: InsightIngredientTier;
  tierLabel: string;
  count: number;
  sharePercent: number | null;
  breakthroughRate: number | null;
  payConversionRate: number | null;
  sevenDayReturnRate: number | null;
}

export interface ATierQualityDashboardReport {
  generatedAt: string;
  totalProfiles: number;
  aTierRate: number | null;
  bTierRate: number | null;
  cTierRate: number | null;
  tierRows: ATierTierRateRow[];
  lowSampleWarning: boolean;
  measurementNote: string;
}
