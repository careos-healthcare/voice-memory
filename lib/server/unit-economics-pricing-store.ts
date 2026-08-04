import type { PoolClient } from "pg";

import {
  dbQuery,
  ensureDatabaseSchema,
  getDatabasePool,
  shouldUsePostgresStorage,
} from "@/lib/server/db";
import {
  COGS_CATEGORIES,
  metricSupportsResource,
  UNIT_ECONOMICS_METRICS,
  type PriceLine,
  type PricingVersion,
} from "@/lib/server/unit-economics-domain";

type PricingCatalog = PricingVersion & { lines: PriceLine[] };

const globalPricing = globalThis as typeof globalThis & {
  __vmUnitEconomicsPricing?: Map<string, PricingCatalog>;
};

function memoryPricing(): Map<string, PricingCatalog> {
  if (!globalPricing.__vmUnitEconomicsPricing) {
    globalPricing.__vmUnitEconomicsPricing = new Map();
  }
  return globalPricing.__vmUnitEconomicsPricing;
}

function validateCatalog(catalog: PricingCatalog): PricingCatalog {
  if (!/^[a-zA-Z0-9._:-]{1,64}$/.test(catalog.versionKey)) {
    throw new Error("Invalid pricing version key.");
  }
  if (
    Number.isNaN(catalog.effectiveFrom.getTime()) ||
    (catalog.effectiveTo !== null &&
      (Number.isNaN(catalog.effectiveTo.getTime()) ||
        catalog.effectiveTo <= catalog.effectiveFrom))
  ) {
    throw new Error("Invalid pricing effective interval.");
  }
  if (catalog.lines.length === 0) throw new Error("Pricing catalog requires price lines.");
  const seen = new Set<string>();
  for (const line of catalog.lines) {
    if (line.versionKey !== catalog.versionKey) throw new Error("Price line version mismatch.");
    if (!UNIT_ECONOMICS_METRICS.includes(line.metric)) throw new Error("Invalid price metric.");
    if (!COGS_CATEGORIES.includes(line.cogsCategory)) throw new Error("Invalid COGS category.");
    if (!metricSupportsResource(line.metric, line.resource)) {
      throw new Error("Price line metric and resource do not match.");
    }
    if (line.unitQuantity <= 0n || line.unitPriceMicroUsd < 0n) {
      throw new Error("Invalid fixed-point price.");
    }
    const key = `${line.metric}\0${line.resource}`;
    if (seen.has(key)) throw new Error("Duplicate pricing line.");
    seen.add(key);
  }
  return catalog;
}

function sameCatalog(left: PricingCatalog, right: PricingCatalog): boolean {
  if (
    left.versionKey !== right.versionKey ||
    left.effectiveFrom.getTime() !== right.effectiveFrom.getTime() ||
    left.effectiveTo?.getTime() !== right.effectiveTo?.getTime() ||
    left.lines.length !== right.lines.length
  ) return false;
  return left.lines.every((line, index) => {
    const other = right.lines[index];
    return other !== undefined &&
      line.metric === other.metric &&
      line.resource === other.resource &&
      line.cogsCategory === other.cogsCategory &&
      line.unitQuantity === other.unitQuantity &&
      line.unitPriceMicroUsd === other.unitPriceMicroUsd &&
      line.costBasis === other.costBasis;
  });
}

function intervalsOverlap(left: PricingVersion, right: PricingVersion): boolean {
  const leftEnd = left.effectiveTo?.getTime() ?? Number.POSITIVE_INFINITY;
  const rightEnd = right.effectiveTo?.getTime() ?? Number.POSITIVE_INFINITY;
  return left.effectiveFrom.getTime() < rightEnd && right.effectiveFrom.getTime() < leftEnd;
}

async function getPricingCatalogWithClient(
  client: PoolClient,
  versionKey: string,
): Promise<PricingCatalog | null> {
  const versions = await client.query<{
    version_key: string;
    effective_from: Date;
    effective_to: Date | null;
  }>(
    `SELECT version_key, effective_from, effective_to
     FROM ue_pricing_versions WHERE version_key = $1`,
    [versionKey],
  );
  const version = versions.rows[0];
  if (!version) return null;
  const lines = await client.query<{
    metric: PriceLine["metric"];
    resource: PriceLine["resource"];
    cogs_category: PriceLine["cogsCategory"];
    unit_quantity: string;
    unit_price_micro_usd: string;
    cost_basis: PriceLine["costBasis"];
  }>(
    `SELECT metric, resource, cogs_category, unit_quantity, unit_price_micro_usd, cost_basis
     FROM ue_price_lines WHERE version_key = $1 ORDER BY metric, resource`,
    [versionKey],
  );
  return {
    versionKey: version.version_key,
    effectiveFrom: new Date(version.effective_from),
    effectiveTo: version.effective_to ? new Date(version.effective_to) : null,
    lines: lines.rows.map((line) => ({
      versionKey,
      metric: line.metric,
      resource: line.resource,
      cogsCategory: line.cogs_category,
      unitQuantity: BigInt(line.unit_quantity),
      unitPriceMicroUsd: BigInt(line.unit_price_micro_usd),
      costBasis: line.cost_basis,
    })),
  };
}

export async function insertPricingCatalog(input: PricingCatalog): Promise<boolean> {
  const catalog = validateCatalog({
    ...input,
    effectiveFrom: new Date(input.effectiveFrom),
    effectiveTo: input.effectiveTo ? new Date(input.effectiveTo) : null,
    lines: [...input.lines].sort((a, b) =>
      `${a.metric}:${a.resource}`.localeCompare(`${b.metric}:${b.resource}`)),
  });

  if (!shouldUsePostgresStorage()) {
    const map = memoryPricing();
    const existing = map.get(catalog.versionKey);
    if (existing) {
      if (!sameCatalog(existing, catalog)) throw new Error("Pricing versions are immutable.");
      return false;
    }
    if ([...map.values()].some((item) => intervalsOverlap(item, catalog))) {
      throw new Error("Pricing effective intervals cannot overlap.");
    }
    map.set(catalog.versionKey, catalog);
    return true;
  }

  await ensureDatabaseSchema();
  const client = await getDatabasePool().connect();
  try {
    await client.query("BEGIN");
    await client.query(
      "SELECT pg_advisory_xact_lock($1::integer, $2::integer)",
      [0x564d5545, 0x50524943],
    );

    const existing = await getPricingCatalogWithClient(client, catalog.versionKey);
    if (existing) {
      if (!sameCatalog(existing, catalog)) throw new Error("Pricing versions are immutable.");
      await client.query("COMMIT");
      return false;
    }

    const overlap = await client.query<{ version_key: string }>(
      `SELECT version_key FROM ue_pricing_versions
       WHERE effective_from < COALESCE($2::timestamptz, 'infinity'::timestamptz)
         AND COALESCE(effective_to, 'infinity'::timestamptz) > $1
       LIMIT 1`,
      [catalog.effectiveFrom, catalog.effectiveTo],
    );
    if (overlap.rows.length > 0) throw new Error("Pricing effective intervals cannot overlap.");

    await client.query(
      `INSERT INTO ue_pricing_versions (version_key, effective_from, effective_to)
       VALUES ($1, $2, $3)`,
      [catalog.versionKey, catalog.effectiveFrom, catalog.effectiveTo],
    );
    for (const line of catalog.lines) {
      await client.query(
        `INSERT INTO ue_price_lines
         (version_key, metric, resource, cogs_category, unit_quantity, unit_price_micro_usd, cost_basis)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          line.versionKey, line.metric, line.resource, line.cogsCategory,
          line.unitQuantity.toString(), line.unitPriceMicroUsd.toString(), line.costBasis,
        ],
      );
    }
    const stored = await getPricingCatalogWithClient(client, catalog.versionKey);
    if (!stored || !sameCatalog(stored, catalog)) throw new Error("Pricing catalog insert mismatch.");
    await client.query("COMMIT");
    return true;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function getPricingCatalog(versionKey: string): Promise<PricingCatalog | null> {
  if (!shouldUsePostgresStorage()) return memoryPricing().get(versionKey) ?? null;
  await ensureDatabaseSchema();
  const client = await getDatabasePool().connect();
  try {
    return await getPricingCatalogWithClient(client, versionKey);
  } finally {
    client.release();
  }
}

export async function selectPricingCatalog(occurredAt: Date): Promise<PricingCatalog | null> {
  if (!shouldUsePostgresStorage()) {
    return [...memoryPricing().values()]
      .filter((item) =>
        item.effectiveFrom <= occurredAt &&
        (item.effectiveTo === null || occurredAt < item.effectiveTo))
      .sort((a, b) => b.effectiveFrom.getTime() - a.effectiveFrom.getTime())[0] ?? null;
  }
  const result = await dbQuery<{ version_key: string }>(
    `SELECT version_key FROM ue_pricing_versions
     WHERE effective_from <= $1 AND (effective_to IS NULL OR effective_to > $1)
     ORDER BY effective_from DESC LIMIT 1`,
    [occurredAt],
  );
  return result.rows[0] ? getPricingCatalog(result.rows[0].version_key) : null;
}

export function resetUnitEconomicsPricingMemoryForTests(): void {
  memoryPricing().clear();
}
