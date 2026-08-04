import {
  isMonetizationPlanId,
  isUsageMeterId,
  MONETIZATION_PLAN_IDS,
  USAGE_METER_IDS,
  type MonetizationPlanId,
  type UsageMeterId,
} from "@/lib/server/monetization-policy";

export const USAGE_ALLOWANCE_CONFIG_ENV =
  "VOICEMEMORY_USAGE_ALLOWANCES_JSON";

export class UsageAllowanceConfigurationError extends Error {
  readonly code = "USAGE_ALLOWANCE_CONFIG_INVALID";

  constructor(message = "Metered usage is not configured on the server.") {
    super(message);
    this.name = "UsageAllowanceConfigurationError";
  }
}

export type UsageAllowances = Readonly<
  Partial<Record<MonetizationPlanId, Readonly<Partial<Record<UsageMeterId, number>>>>>
>;

export function readUsageAllowances(
  raw = process.env[USAGE_ALLOWANCE_CONFIG_ENV],
): UsageAllowances {
  if (!raw?.trim()) throw new UsageAllowanceConfigurationError();
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new UsageAllowanceConfigurationError();
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new UsageAllowanceConfigurationError();
  }

  const result: Partial<Record<MonetizationPlanId, Partial<Record<UsageMeterId, number>>>> =
    {};
  for (const [plan, meters] of Object.entries(value)) {
    if (!isMonetizationPlanId(plan) || !meters || typeof meters !== "object" ||
        Array.isArray(meters)) {
      throw new UsageAllowanceConfigurationError();
    }
    const parsed: Partial<Record<UsageMeterId, number>> = {};
    for (const [meter, allowance] of Object.entries(meters)) {
      if (!isUsageMeterId(meter) || !Number.isSafeInteger(allowance) ||
          (allowance as number) < 0) {
        throw new UsageAllowanceConfigurationError();
      }
      parsed[meter] = allowance as number;
    }
    result[plan] = parsed;
  }
  return result;
}

export function usageAllowanceFor(
  plan: MonetizationPlanId,
  meter: UsageMeterId,
  raw?: string,
): number {
  const allowance = readUsageAllowances(raw)[plan]?.[meter];
  if (allowance === undefined) throw new UsageAllowanceConfigurationError();
  return allowance;
}

export function validateProductionUsageAllowances(
  raw = process.env[USAGE_ALLOWANCE_CONFIG_ENV],
): string[] {
  let allowances: UsageAllowances;
  try {
    allowances = readUsageAllowances(raw);
  } catch {
    return [`${USAGE_ALLOWANCE_CONFIG_ENV} must be valid JSON with integer allowances.`];
  }
  const errors: string[] = [];
  for (const plan of MONETIZATION_PLAN_IDS) {
    for (const meter of USAGE_METER_IDS) {
      if (allowances[plan]?.[meter] === undefined) {
        errors.push(`${USAGE_ALLOWANCE_CONFIG_ENV} is missing ${plan}.${meter}.`);
      }
    }
  }
  return errors;
}
