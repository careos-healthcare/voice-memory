import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  COGS_CATEGORIES,
  metricSupportsResource,
  UNIT_ECONOMICS_METRICS,
  UNIT_ECONOMICS_RESOURCES,
  type PriceLine,
} from "@/lib/server/unit-economics-domain";

const DEFAULT_CATALOG_PATH = "config/unit-economics/pricing-catalog.v1.json";
const INTEGER = /^(0|[1-9][0-9]*)$/;
const BILLABLE_METRICS = UNIT_ECONOMICS_METRICS.filter(
  (metric): metric is PriceLine["metric"] =>
    metric !== "revenue" && metric !== "credits" && metric !== "adjustments",
);

export const REQUIRED_PRICING_PAIRS = BILLABLE_METRICS.flatMap((metric) =>
  UNIT_ECONOMICS_RESOURCES
    .filter((resource) => metricSupportsResource(metric, resource))
    .map((resource) => `${metric}\0${resource}`),
).sort();

export interface PricingCatalogMetadata {
  schemaVersion: 1;
  versionKey: string;
  effectiveFrom: string;
  effectiveTo: string | null;
  currency: "USD";
  source: {
    asOf: string;
    reference: string;
    assumption: string;
  };
  lines: Array<{
    metric: PriceLine["metric"];
    resource: PriceLine["resource"];
    cogsCategory: PriceLine["cogsCategory"];
    unitQuantity: string;
    unitPriceMicroUsd: string;
    costBasis: PriceLine["costBasis"];
  }>;
}

export function pricingCoverageErrors(
  lines: readonly Pick<PriceLine, "metric" | "resource">[],
): string[] {
  const actual = new Set(lines.map((line) => `${line.metric}\0${line.resource}`));
  return REQUIRED_PRICING_PAIRS
    .filter((pair) => !actual.has(pair))
    .map((pair) => `Missing price line: ${pair.replace("\0", " / ")}`);
}

export function parsePricingCatalog(value: unknown): {
  metadata: PricingCatalogMetadata;
  catalog: {
    versionKey: string;
    effectiveFrom: Date;
    effectiveTo: Date | null;
    lines: PriceLine[];
  };
} {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Pricing catalog must be an object.");
  }
  const raw = value as Partial<PricingCatalogMetadata>;
  if (
    raw.schemaVersion !== 1 ||
    typeof raw.versionKey !== "string" ||
    typeof raw.effectiveFrom !== "string" ||
    (raw.effectiveTo !== null && typeof raw.effectiveTo !== "string") ||
    raw.currency !== "USD" ||
    !raw.source ||
    typeof raw.source.asOf !== "string" ||
    typeof raw.source.reference !== "string" ||
    typeof raw.source.assumption !== "string" ||
    raw.source.assumption.trim().length < 20 ||
    !Array.isArray(raw.lines)
  ) {
    throw new Error("Pricing catalog metadata is incomplete.");
  }
  const effectiveFrom = new Date(raw.effectiveFrom);
  const effectiveTo = raw.effectiveTo === null ? null : new Date(raw.effectiveTo);
  if (
    Number.isNaN(effectiveFrom.getTime()) ||
    (effectiveTo !== null &&
      (Number.isNaN(effectiveTo.getTime()) || effectiveTo <= effectiveFrom))
  ) {
    throw new Error("Pricing catalog effective interval is invalid.");
  }
  const lines: PriceLine[] = raw.lines.map((line) => {
    if (
      !line ||
      !UNIT_ECONOMICS_METRICS.includes(line.metric) ||
      !UNIT_ECONOMICS_RESOURCES.includes(line.resource) ||
      !COGS_CATEGORIES.includes(line.cogsCategory) ||
      !metricSupportsResource(line.metric, line.resource) ||
      !INTEGER.test(line.unitQuantity) ||
      line.unitQuantity === "0" ||
      !INTEGER.test(line.unitPriceMicroUsd) ||
      (line.costBasis !== "exact" && line.costBasis !== "estimated")
    ) {
      throw new Error("Pricing catalog contains an invalid line.");
    }
    return {
      versionKey: raw.versionKey!,
      metric: line.metric,
      resource: line.resource,
      cogsCategory: line.cogsCategory,
      unitQuantity: BigInt(line.unitQuantity),
      unitPriceMicroUsd: BigInt(line.unitPriceMicroUsd),
      costBasis: line.costBasis,
    };
  });
  const coverageErrors = pricingCoverageErrors(lines);
  if (coverageErrors.length > 0) throw new Error(coverageErrors.join(" "));
  return {
    metadata: raw as PricingCatalogMetadata,
    catalog: {
      versionKey: raw.versionKey,
      effectiveFrom,
      effectiveTo,
      lines,
    },
  };
}

export async function loadPricingCatalog(
  configuredPath = process.env.VOICEMEMORY_UNIT_ECONOMICS_PRICING_CATALOG_PATH,
) {
  const catalogPath = path.resolve(process.cwd(), configuredPath?.trim() || DEFAULT_CATALOG_PATH);
  const raw = await readFile(catalogPath, "utf8");
  return parsePricingCatalog(JSON.parse(raw) as unknown);
}
