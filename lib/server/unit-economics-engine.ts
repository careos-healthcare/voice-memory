import {
  calculateCostMicroUsd,
  type MeasurementBasis,
  subjectKeyVersion,
  utcDay,
  type DailySubjectRollup,
  type PriceLine,
  type UnitEconomicsDimensions,
  type UnitEconomicsResource,
  type UsageLedgerRow,
} from "@/lib/server/unit-economics-domain";
import {
  appendUsageLedgerRow,
  listUsageLedgerRows,
} from "@/lib/server/unit-economics-ledger-store";
import { selectPricingCatalog } from "@/lib/server/unit-economics-pricing-store";
import { writeDailySubjectRollup } from "@/lib/server/unit-economics-rollup-store";
import { createEconomicsEventKey } from "@/lib/server/unit-economics-subject-key";

type BillableMetric = PriceLine["metric"];

export interface PricedUsageInput {
  eventParts: readonly string[];
  subjectKey: string;
  metric: BillableMetric;
  resource: UnitEconomicsResource;
  quantity: bigint;
  dimensions?: UnitEconomicsDimensions;
  occurredAt: Date;
  measurementBasis: MeasurementBasis;
}

export async function recordPricedUsage(input: PricedUsageInput): Promise<boolean> {
  if (input.quantity < 0n) throw new Error("Priced usage quantity cannot be negative.");
  const catalog = await selectPricingCatalog(input.occurredAt);
  if (!catalog) throw new Error("No pricing version applies to occurredAt.");
  const line = catalog.lines.find(
    (candidate) => candidate.metric === input.metric && candidate.resource === input.resource,
  );
  if (!line) throw new Error("No matching price line.");
  const amount = calculateCostMicroUsd(
    input.quantity,
    line.unitPriceMicroUsd,
    line.unitQuantity,
  );
  return appendUsageLedgerRow({
    eventKey: createEconomicsEventKey(...input.eventParts),
    subjectKey: input.subjectKey,
    subjectKeyVersion: subjectKeyVersion(input.subjectKey),
    metric: input.metric,
    resource: input.resource,
    quantity: input.quantity,
    category: line.cogsCategory,
    exactCostMicroUsd: line.costBasis === "exact" ? amount : 0n,
    estimatedCostMicroUsd: line.costBasis === "estimated" ? amount : 0n,
    measurementBasis: input.measurementBasis,
    pricingVersionKey: catalog.versionKey,
    dimensions: input.dimensions ?? {},
    occurredAt: input.occurredAt,
    day: utcDay(input.occurredAt),
  });
}

export interface MoneyLedgerInput {
  eventParts: readonly string[];
  subjectKey: string;
  metric: "revenue" | "credits" | "adjustments";
  amountMicroUsd: bigint;
  occurredAt: Date;
  resource: UnitEconomicsResource;
  dimensions?: UnitEconomicsDimensions;
}

export async function recordMoneyLedgerRow(input: MoneyLedgerInput): Promise<boolean> {
  if (input.metric !== "adjustments" && input.amountMicroUsd < 0n) {
    throw new Error("Use an adjustment row for negative corrections.");
  }
  return appendUsageLedgerRow({
    eventKey: createEconomicsEventKey(...input.eventParts),
    subjectKey: input.subjectKey,
    subjectKeyVersion: subjectKeyVersion(input.subjectKey),
    metric: input.metric,
    resource: input.resource,
    quantity: input.metric === "adjustments" ? input.amountMicroUsd : 1n,
    category: input.metric,
    exactCostMicroUsd: input.amountMicroUsd,
    estimatedCostMicroUsd: 0n,
    measurementBasis: "exact",
    pricingVersionKey: null,
    dimensions: input.dimensions ?? {},
    occurredAt: input.occurredAt,
    day: utcDay(input.occurredAt),
  });
}

function rowAmount(row: UsageLedgerRow): bigint {
  return row.exactCostMicroUsd + row.estimatedCostMicroUsd;
}

function safeMarginBps(margin: bigint, netRevenue: bigint): number | null {
  if (netRevenue <= 0n) return null;
  const value = (margin * 10_000n) / netRevenue;
  if (value > 2_147_483_647n || value < -2_147_483_648n) {
    throw new Error("Margin basis points exceed storage range.");
  }
  return Number(value);
}

export function calculateDailyRollup(
  subjectKey: string,
  day: string,
  rows: readonly UsageLedgerRow[],
): DailySubjectRollup {
  const rollup: DailySubjectRollup = {
    subjectKey,
    subjectKeyVersion: subjectKeyVersion(subjectKey),
    day,
    revenueMicroUsd: 0n,
    creditsMicroUsd: 0n,
    adjustmentsMicroUsd: 0n,
    aiCogsMicroUsd: 0n,
    transcriptionCogsMicroUsd: 0n,
    storageCogsMicroUsd: 0n,
    bandwidthCogsMicroUsd: 0n,
    liveCogsMicroUsd: 0n,
    imageCogsMicroUsd: 0n,
    totalCogsMicroUsd: 0n,
    contributionMarginMicroUsd: 0n,
    marginBps: null,
  };
  for (const row of rows) {
    if (row.subjectKey !== subjectKey || row.day !== day) {
      throw new Error("Cannot reconcile rows from another subject or day.");
    }
    const amount = rowAmount(row);
    switch (row.category) {
      case "revenue": rollup.revenueMicroUsd += amount; break;
      case "credits": rollup.creditsMicroUsd += amount; break;
      case "adjustments": rollup.adjustmentsMicroUsd += amount; break;
      case "ai": rollup.aiCogsMicroUsd += amount; break;
      case "transcription": rollup.transcriptionCogsMicroUsd += amount; break;
      case "storage": rollup.storageCogsMicroUsd += amount; break;
      case "bandwidth": rollup.bandwidthCogsMicroUsd += amount; break;
      case "live": rollup.liveCogsMicroUsd += amount; break;
      case "image": rollup.imageCogsMicroUsd += amount; break;
    }
  }
  rollup.totalCogsMicroUsd =
    rollup.aiCogsMicroUsd + rollup.transcriptionCogsMicroUsd +
    rollup.storageCogsMicroUsd + rollup.bandwidthCogsMicroUsd +
    rollup.liveCogsMicroUsd + rollup.imageCogsMicroUsd;
  const netRevenue = rollup.revenueMicroUsd - rollup.creditsMicroUsd;
  rollup.contributionMarginMicroUsd =
    netRevenue + rollup.adjustmentsMicroUsd - rollup.totalCogsMicroUsd;
  rollup.marginBps = safeMarginBps(rollup.contributionMarginMicroUsd, netRevenue);
  return rollup;
}

export async function reconcileDailySubjectRollup(
  subjectKey: string,
  day: string,
): Promise<DailySubjectRollup> {
  const rows = await listUsageLedgerRows(subjectKey, day);
  const rollup = calculateDailyRollup(subjectKey, day, rows);
  await writeDailySubjectRollup(rollup);
  return rollup;
}
