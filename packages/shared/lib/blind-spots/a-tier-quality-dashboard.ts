import { enrichAllBlindSpotQualityRecords } from "@/lib/blind-spots/blind-spot-quality-enrichment";
import { readAllBlindSpotQualityRecords } from "@/lib/blind-spots/blind-spot-quality-storage";
import { buildInsightIngredientProfile } from "@/lib/insights/insight-ingredient-optimizer";
import { readLocalEvents } from "@/lib/local-analytics";
import { readFunnelState } from "@/lib/retention/first-week-funnel";
import type { ATierQualityDashboardReport, ATierTierRateRow } from "@/types/a-tier-prioritization";
import type { InsightIngredientTier } from "@/types/insight-ingredient-optimizer";
import type { BlindSpotQualityEnrichedRecord } from "@/types/blind-spot-quality";

const ALL_TIERS: InsightIngredientTier[] = ["a_tier", "b_tier", "c_tier", "d_tier"];
const PAY_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const RETURN_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function profileFromRecord(record: BlindSpotQualityEnrichedRecord) {
  return buildInsightIngredientProfile({
    reviewId: record.reviewId,
    blindSpotId: record.blindSpotId,
    contradictionPresent: record.contradictionPresent,
    costEvidencePresent: record.costEvidencePresent,
    crossLifeAreaPresent: record.crossLifeAreaPresent,
    failedPredictionPresent: record.failedPredictionPresent,
    evidenceStrength: record.evidenceStrength,
    scorecardScore: record.scorecardScore,
    createdAt: record.generatedAt,
  });
}

function hadUpgradeAfter(iso: string): boolean {
  const start = new Date(iso).getTime();
  const end = start + PAY_WINDOW_MS;
  return readLocalEvents().some((event) => {
    if (event.name !== "upgrade_clicked") return false;
    const at = new Date(event.at).getTime();
    return at >= start && at <= end;
  });
}

function hadSevenDayReturnAfter(iso: string): boolean {
  const start = new Date(iso).getTime();
  const end = start + RETURN_WINDOW_MS;
  const events = readLocalEvents();
  const funnelReturn = readFunnelState().stages.return_within_7d?.at;
  if (funnelReturn) {
    const at = new Date(funnelReturn).getTime();
    if (at >= start && at <= end) return true;
  }
  return events.some((event) => {
    if (event.name !== "entry_recorded") return false;
    const at = new Date(event.at).getTime();
    return at >= start && at <= end;
  });
}

function buildTierRows(enriched: BlindSpotQualityEnrichedRecord[]): ATierTierRateRow[] {
  const total = enriched.length;
  return ALL_TIERS.map((tier) => {
    const rows = enriched.filter((r) => profileFromRecord(r).tier === tier);
    const count = rows.length;
    return {
      tier,
      tierLabel: tier.replace("_", "-").toUpperCase(),
      count,
      sharePercent: pct(count, total),
      breakthroughRate: pct(rows.filter((r) => r.outcomes.breakthrough).length, count),
      payConversionRate: pct(rows.filter((r) => hadUpgradeAfter(r.generatedAt)).length, count),
      sevenDayReturnRate: pct(
        rows.filter((r) => hadSevenDayReturnAfter(r.generatedAt)).length,
        count,
      ),
    };
  });
}

export function buildATierQualityDashboardReport(
  records = readAllBlindSpotQualityRecords(),
): ATierQualityDashboardReport {
  const enriched = enrichAllBlindSpotQualityRecords(records);
  const tierRows = buildTierRows(enriched);
  const total = enriched.length;

  const aCount = tierRows.find((r) => r.tier === "a_tier")?.count ?? 0;
  const bCount = tierRows.find((r) => r.tier === "b_tier")?.count ?? 0;
  const cCount = tierRows.find((r) => r.tier === "c_tier")?.count ?? 0;

  return {
    generatedAt: new Date().toISOString(),
    totalProfiles: total,
    aTierRate: pct(aCount, total),
    bTierRate: pct(bCount, total),
    cTierRate: pct(cCount, total),
    tierRows,
    lowSampleWarning: total < 8,
    measurementNote:
      "Pay conversion and 7-day return use device-local timestamps after each blind spot review — directional only.",
  };
}
