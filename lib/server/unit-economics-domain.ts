export const UNIT_ECONOMICS_METRICS = [
  "ai_input_tokens",
  "ai_output_tokens",
  "ai_cached_tokens",
  "ai_reasoning_tokens",
  "transcription_audio_milliseconds",
  "storage_snapshot_bytes",
  "ingress_bytes",
  "egress_bytes",
  "retrieval_bytes",
  "live_session_milliseconds",
  "image_generations",
  "revenue",
  "credits",
  "adjustments",
] as const;

export type UnitEconomicsMetric = (typeof UNIT_ECONOMICS_METRICS)[number];

export const COGS_CATEGORIES = [
  "ai",
  "transcription",
  "storage",
  "bandwidth",
  "live",
  "image",
] as const;
export type CogsCategory = (typeof COGS_CATEGORIES)[number];
export type LedgerCategory = CogsCategory | "revenue" | "credits" | "adjustments";
export type CostBasis = "exact" | "estimated";
export type MeasurementBasis = "exact" | "estimated";

export const UNIT_ECONOMICS_RESOURCES = [
  "openai.gpt-4o-mini",
  "openai.gpt-5",
  "openai.gpt-5.5",
  "openai.gpt-5.5-pro",
  "openai.whisper-1",
  "google.gemini-live",
  "storage.snapshot",
  "network.ingress",
  "network.egress",
  "network.retrieval",
  "image.atmosphere",
  "stripe.subscription",
  "revenuecat.subscription",
  "credit.subscription",
  "adjustment.correction",
] as const;
export type UnitEconomicsResource = (typeof UNIT_ECONOMICS_RESOURCES)[number];

export const UNIT_ECONOMICS_DIMENSION_KEYS = [
  "provider",
  "model",
  "region",
  "plan",
  "platform",
] as const;
export type UnitEconomicsDimensionKey = (typeof UNIT_ECONOMICS_DIMENSION_KEYS)[number];
export const UNIT_ECONOMICS_DIMENSION_VALUES = {
  provider: ["openai", "google", "stripe", "revenuecat", "aws", "cloudflare", "internal", "other"],
  model: [
    "gpt-4o-mini",
    "gpt-5",
    "gpt-5.5",
    "gpt-5.5-pro",
    "whisper-1",
    "gemini-live",
    "other",
  ],
  region: ["us", "eu", "global", "other"],
  plan: ["free", "pro", "trial", "other"],
  platform: ["web", "ios", "android", "server", "other"],
} as const;
export type UnitEconomicsDimensions = {
  [Key in UnitEconomicsDimensionKey]?: (typeof UNIT_ECONOMICS_DIMENSION_VALUES)[Key][number];
};

export interface PricingVersion {
  versionKey: string;
  effectiveFrom: Date;
  effectiveTo: Date | null;
}

export interface PriceLine {
  versionKey: string;
  metric: Exclude<UnitEconomicsMetric, "revenue" | "credits" | "adjustments">;
  resource: UnitEconomicsResource;
  cogsCategory: CogsCategory;
  unitQuantity: bigint;
  unitPriceMicroUsd: bigint;
  costBasis: CostBasis;
}

export interface UsageLedgerRow {
  eventKey: string;
  subjectKey: string;
  subjectKeyVersion: number;
  metric: UnitEconomicsMetric;
  resource: UnitEconomicsResource;
  quantity: bigint;
  category: LedgerCategory;
  exactCostMicroUsd: bigint;
  estimatedCostMicroUsd: bigint;
  measurementBasis: MeasurementBasis;
  pricingVersionKey: string | null;
  dimensions: UnitEconomicsDimensions;
  occurredAt: Date;
  day: string;
}

export interface DailySubjectRollup {
  subjectKey: string;
  subjectKeyVersion: number;
  day: string;
  revenueMicroUsd: bigint;
  creditsMicroUsd: bigint;
  adjustmentsMicroUsd: bigint;
  aiCogsMicroUsd: bigint;
  transcriptionCogsMicroUsd: bigint;
  storageCogsMicroUsd: bigint;
  bandwidthCogsMicroUsd: bigint;
  liveCogsMicroUsd: bigint;
  imageCogsMicroUsd: bigint;
  totalCogsMicroUsd: bigint;
  contributionMarginMicroUsd: bigint;
  marginBps: number | null;
}

const metricSet = new Set<string>(UNIT_ECONOMICS_METRICS);
const resourceSet = new Set<string>(UNIT_ECONOMICS_RESOURCES);
const dimensionKeySet = new Set<string>(UNIT_ECONOMICS_DIMENSION_KEYS);
const SUBJECT_KEY = /^ue:v([1-9][0-9]*):[A-Za-z0-9_-]{43}$/;
const EVENT_KEY = /^uee:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$/;

const ALLOWED_CATEGORIES: Record<UnitEconomicsMetric, readonly LedgerCategory[]> = {
  ai_input_tokens: ["ai"],
  ai_output_tokens: ["ai"],
  ai_cached_tokens: ["ai"],
  ai_reasoning_tokens: ["ai"],
  transcription_audio_milliseconds: ["transcription"],
  storage_snapshot_bytes: ["storage"],
  ingress_bytes: ["bandwidth"],
  egress_bytes: ["bandwidth"],
  retrieval_bytes: ["bandwidth"],
  live_session_milliseconds: ["live"],
  image_generations: ["image"],
  revenue: ["revenue"],
  credits: ["credits"],
  adjustments: ["adjustments"],
};
const ALLOWED_RESOURCES: Record<UnitEconomicsMetric, readonly UnitEconomicsResource[]> = {
  ai_input_tokens: [
    "openai.gpt-4o-mini", "openai.gpt-5", "openai.gpt-5.5", "openai.gpt-5.5-pro",
  ],
  ai_output_tokens: [
    "openai.gpt-4o-mini", "openai.gpt-5", "openai.gpt-5.5", "openai.gpt-5.5-pro",
  ],
  ai_cached_tokens: [
    "openai.gpt-4o-mini", "openai.gpt-5", "openai.gpt-5.5", "openai.gpt-5.5-pro",
  ],
  ai_reasoning_tokens: [
    "openai.gpt-4o-mini", "openai.gpt-5", "openai.gpt-5.5", "openai.gpt-5.5-pro",
  ],
  transcription_audio_milliseconds: ["openai.whisper-1"],
  storage_snapshot_bytes: ["storage.snapshot"],
  ingress_bytes: ["network.ingress"],
  egress_bytes: ["network.egress"],
  retrieval_bytes: ["network.retrieval"],
  live_session_milliseconds: ["google.gemini-live"],
  image_generations: ["image.atmosphere"],
  revenue: ["stripe.subscription", "revenuecat.subscription"],
  credits: ["credit.subscription"],
  adjustments: ["adjustment.correction"],
};

export function metricSupportsResource(
  metric: UnitEconomicsMetric,
  resource: UnitEconomicsResource,
): boolean {
  return ALLOWED_RESOURCES[metric].includes(resource);
}

export function subjectKeyVersion(subjectKey: string): number {
  const match = SUBJECT_KEY.exec(subjectKey);
  if (!match) throw new Error("Invalid unit economics subject key.");
  return Number(match[1]);
}

export function utcDay(occurredAt: Date): string {
  if (Number.isNaN(occurredAt.getTime())) throw new Error("occurredAt must be valid.");
  return occurredAt.toISOString().slice(0, 10);
}

export function validateDimensions(
  value: UnitEconomicsDimensions = {},
): UnitEconomicsDimensions {
  const clean: UnitEconomicsDimensions = {};
  for (const [key, raw] of Object.entries(value)) {
    if (!dimensionKeySet.has(key)) throw new Error(`Unsupported economics dimension: ${key}`);
    const allowed = UNIT_ECONOMICS_DIMENSION_VALUES[key as UnitEconomicsDimensionKey];
    if (
      typeof raw !== "string" ||
      !(allowed as readonly string[]).includes(raw)
    ) {
      throw new Error(`Invalid economics dimension value for ${key}.`);
    }
    Object.assign(clean, { [key]: raw });
  }
  return clean;
}

export function validateUsageLedgerRow(row: UsageLedgerRow): UsageLedgerRow {
  if (!EVENT_KEY.test(row.eventKey)) throw new Error("Invalid economics event key.");
  const version = subjectKeyVersion(row.subjectKey);
  if (version !== row.subjectKeyVersion) throw new Error("Subject key version mismatch.");
  if (!metricSet.has(row.metric)) throw new Error("Unsupported economics metric.");
  if (!ALLOWED_CATEGORIES[row.metric].includes(row.category)) {
    throw new Error("Metric and category do not match.");
  }
  if (!resourceSet.has(row.resource)) {
    throw new Error("Invalid economics resource.");
  }
  if (!metricSupportsResource(row.metric, row.resource)) {
    throw new Error("Metric and resource do not match.");
  }
  if (row.metric !== "adjustments" && row.quantity < 0n) {
    throw new Error("Only adjustment rows may have negative quantities.");
  }
  if (
    row.metric !== "adjustments" &&
    (row.exactCostMicroUsd < 0n || row.estimatedCostMicroUsd < 0n)
  ) {
    throw new Error("Only adjustment rows may have negative currency.");
  }
  if (row.exactCostMicroUsd !== 0n && row.estimatedCostMicroUsd !== 0n) {
    throw new Error("A row cannot be both exact and estimated.");
  }
  if (row.measurementBasis !== "exact" && row.measurementBasis !== "estimated") {
    throw new Error("Invalid measurement basis.");
  }
  if (utcDay(row.occurredAt) !== row.day) throw new Error("Ledger day must be UTC occurredAt day.");
  return { ...row, dimensions: validateDimensions(row.dimensions) };
}

export function calculateCostMicroUsd(
  quantity: bigint,
  unitPriceMicroUsd: bigint,
  unitQuantity: bigint,
): bigint {
  if (quantity < 0n || unitPriceMicroUsd < 0n || unitQuantity <= 0n) {
    throw new Error("Cost operands must be nonnegative and unit quantity positive.");
  }
  const numerator = quantity * unitPriceMicroUsd;
  return (numerator + unitQuantity / 2n) / unitQuantity;
}
