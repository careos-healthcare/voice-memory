import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import {
  validateUsageLedgerRow,
  type UsageLedgerRow,
} from "@/lib/server/unit-economics-domain";

const globalLedger = globalThis as typeof globalThis & {
  __vmUnitEconomicsLedger?: Map<string, UsageLedgerRow>;
};

function memoryLedger(): Map<string, UsageLedgerRow> {
  if (!globalLedger.__vmUnitEconomicsLedger) {
    globalLedger.__vmUnitEconomicsLedger = new Map();
  }
  return globalLedger.__vmUnitEconomicsLedger;
}

function cloneRow(row: UsageLedgerRow): UsageLedgerRow {
  return { ...row, dimensions: { ...row.dimensions }, occurredAt: new Date(row.occurredAt) };
}

export async function appendUsageLedgerRow(input: UsageLedgerRow): Promise<boolean> {
  const row = validateUsageLedgerRow(cloneRow(input));
  if (!shouldUsePostgresStorage()) {
    const ledger = memoryLedger();
    if (ledger.has(row.eventKey)) return false;
    ledger.set(row.eventKey, row);
    return true;
  }
  const result = await dbQuery(
    `INSERT INTO ue_usage_ledger
     (event_key, subject_key, subject_key_version, metric, resource, quantity, category,
      exact_cost_micro_usd, estimated_cost_micro_usd, measurement_basis,
      pricing_version_key, dimensions, occurred_at, day)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, $13, $14)
     ON CONFLICT (event_key) DO NOTHING`,
    [
      row.eventKey, row.subjectKey, row.subjectKeyVersion, row.metric, row.resource,
      row.quantity.toString(), row.category, row.exactCostMicroUsd.toString(),
      row.estimatedCostMicroUsd.toString(), row.measurementBasis, row.pricingVersionKey,
      JSON.stringify(row.dimensions), row.occurredAt, row.day,
    ],
  );
  return (result.rowCount ?? 0) > 0;
}

type DatabaseLedgerRow = {
  event_key: string;
  subject_key: string;
  subject_key_version: number;
  metric: UsageLedgerRow["metric"];
  resource: UsageLedgerRow["resource"];
  quantity: string;
  category: UsageLedgerRow["category"];
  exact_cost_micro_usd: string;
  estimated_cost_micro_usd: string;
  measurement_basis: UsageLedgerRow["measurementBasis"];
  pricing_version_key: string | null;
  dimensions: UsageLedgerRow["dimensions"];
  occurred_at: Date;
  day: Date | string;
};

function fromDatabase(row: DatabaseLedgerRow): UsageLedgerRow {
  return {
    eventKey: row.event_key,
    subjectKey: row.subject_key,
    subjectKeyVersion: row.subject_key_version,
    metric: row.metric,
    resource: row.resource,
    quantity: BigInt(row.quantity),
    category: row.category,
    exactCostMicroUsd: BigInt(row.exact_cost_micro_usd),
    estimatedCostMicroUsd: BigInt(row.estimated_cost_micro_usd),
    measurementBasis: row.measurement_basis,
    pricingVersionKey: row.pricing_version_key,
    dimensions: row.dimensions,
    occurredAt: new Date(row.occurred_at),
    day: typeof row.day === "string" ? row.day.slice(0, 10) : row.day.toISOString().slice(0, 10),
  };
}

export async function listUsageLedgerRows(
  subjectKey: string,
  day: string,
): Promise<UsageLedgerRow[]> {
  if (!shouldUsePostgresStorage()) {
    return [...memoryLedger().values()]
      .filter((row) => row.subjectKey === subjectKey && row.day === day)
      .sort((a, b) => a.eventKey.localeCompare(b.eventKey))
      .map(cloneRow);
  }
  const result = await dbQuery<DatabaseLedgerRow>(
    `SELECT event_key, subject_key, subject_key_version, metric, resource, quantity, category,
            exact_cost_micro_usd, estimated_cost_micro_usd, measurement_basis,
            pricing_version_key, dimensions, occurred_at, day
     FROM ue_usage_ledger WHERE subject_key = $1 AND day = $2 ORDER BY event_key`,
    [subjectKey, day],
  );
  return result.rows.map(fromDatabase);
}

export interface EconomicsSubjectDay {
  subjectKey: string;
  day: string;
}

export async function listUsageSubjectDays(
  fromDay: string,
  toDay: string,
  limit = 10_000,
): Promise<EconomicsSubjectDay[]> {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fromDay) || !/^\d{4}-\d{2}-\d{2}$/.test(toDay)) {
    throw new Error("Invalid reconciliation date range.");
  }
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 10_000) {
    throw new Error("Invalid reconciliation query limit.");
  }
  if (!shouldUsePostgresStorage()) {
    const unique = new Map<string, EconomicsSubjectDay>();
    for (const row of memoryLedger().values()) {
      if (row.day < fromDay || row.day > toDay) continue;
      unique.set(`${row.subjectKey}\0${row.day}`, {
        subjectKey: row.subjectKey,
        day: row.day,
      });
    }
    return [...unique.values()]
      .sort((a, b) => a.day.localeCompare(b.day) || a.subjectKey.localeCompare(b.subjectKey))
      .slice(0, limit);
  }
  const result = await dbQuery<{ subject_key: string; day: string | Date }>(
    `SELECT DISTINCT subject_key, day
     FROM ue_usage_ledger
     WHERE day >= $1 AND day <= $2
     ORDER BY day, subject_key
     LIMIT $3`,
    [fromDay, toDay, limit],
  );
  return result.rows.map((row) => ({
    subjectKey: row.subject_key,
    day: row.day instanceof Date
      ? row.day.toISOString().slice(0, 10)
      : String(row.day).slice(0, 10),
  }));
}

export function resetUnitEconomicsLedgerMemoryForTests(): void {
  memoryLedger().clear();
}

export async function summarizeTrustedRevenueByPlan(
  from: Date,
  to: Date,
): Promise<{
  attributed: Array<{ plan: "free" | "pro" | "trial" | "other"; revenueMicroUsd: bigint }>;
  unattributedRevenueMicroUsd: bigint;
}> {
  if (to <= from) throw new Error("REVENUE_REPORT_RANGE_INVALID");
  if (!shouldUsePostgresStorage()) {
    const sums = new Map<"free" | "pro" | "trial" | "other", bigint>();
    let unattributedRevenueMicroUsd = 0n;
    for (const row of memoryLedger().values()) {
      if (
        row.metric !== "revenue" ||
        row.occurredAt < from ||
        row.occurredAt >= to
      ) continue;
      const plan = row.dimensions.plan;
      if (!plan) {
        unattributedRevenueMicroUsd += row.exactCostMicroUsd;
      } else {
        sums.set(plan, (sums.get(plan) ?? 0n) + row.exactCostMicroUsd);
      }
    }
    return {
      attributed: [...sums].map(([plan, revenueMicroUsd]) => ({
        plan,
        revenueMicroUsd,
      })),
      unattributedRevenueMicroUsd,
    };
  }
  const result = await dbQuery<{
    plan: "free" | "pro" | "trial" | "other" | null;
    revenue_micro_usd: string;
  }>(
    `SELECT dimensions->>'plan' AS plan,
            sum(exact_cost_micro_usd)::text AS revenue_micro_usd
     FROM ue_usage_ledger
     WHERE metric = 'revenue' AND occurred_at >= $1 AND occurred_at < $2
     GROUP BY dimensions->>'plan'`,
    [from, to],
  );
  let unattributedRevenueMicroUsd = 0n;
  const attributed: Array<{
    plan: "free" | "pro" | "trial" | "other";
    revenueMicroUsd: bigint;
  }> = [];
  for (const row of result.rows) {
    if (row.plan) {
      attributed.push({
        plan: row.plan,
        revenueMicroUsd: BigInt(row.revenue_micro_usd),
      });
    } else {
      unattributedRevenueMicroUsd += BigInt(row.revenue_micro_usd);
    }
  }
  return { attributed, unattributedRevenueMicroUsd };
}
