import { hasDatabaseUrl } from "@/lib/server/db";
import { getMarginThresholdConfig } from "@/lib/server/unit-economics-breach-store";
import { configuredEconomicsHmacVersions } from "@/lib/server/unit-economics-subject-key";

function enabled(value: string | undefined): boolean {
  return value?.trim().toLowerCase() === "true";
}

export function isUnitEconomicsEnabled(): boolean {
  return enabled(process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED);
}

export function isUnitEconomicsPricingRequired(): boolean {
  const value = process.env.VOICEMEMORY_UNIT_ECONOMICS_PRICING_REQUIRED?.trim().toLowerCase();
  if (value === undefined || value === "") return true;
  if (value !== "true" && value !== "false") {
    throw new Error("VOICEMEMORY_UNIT_ECONOMICS_PRICING_REQUIRED must be true or false.");
  }
  return value === "true";
}

export function unitEconomicsMaxReconciliationDays(): number {
  const raw = process.env.VOICEMEMORY_UNIT_ECONOMICS_MAX_RECONCILIATION_DAYS?.trim() || "31";
  if (!/^[1-9][0-9]*$/.test(raw)) {
    throw new Error("VOICEMEMORY_UNIT_ECONOMICS_MAX_RECONCILIATION_DAYS must be a positive integer.");
  }
  const days = Number(raw);
  if (!Number.isSafeInteger(days) || days > 366) {
    throw new Error("Unit economics reconciliation days must not exceed 366.");
  }
  return days;
}

export function validateUnitEconomicsConfiguration(): string[] {
  if (!isUnitEconomicsEnabled()) return [];
  const errors: string[] = [];
  if (!hasDatabaseUrl() && process.env.NODE_ENV === "production") {
    errors.push("DATABASE_URL is required when unit economics is enabled in production.");
  }
  if (
    process.env.NODE_ENV === "production" &&
    !process.env.CRON_SECRET?.trim()
  ) {
    errors.push("CRON_SECRET is required when unit economics is enabled in production.");
  }
  try {
    configuredEconomicsHmacVersions();
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }
  try {
    getMarginThresholdConfig();
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }
  try {
    isUnitEconomicsPricingRequired();
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }
  try {
    unitEconomicsMaxReconciliationDays();
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }
  return errors;
}

export function assertProductionUnitEconomicsIsDurable(): void {
  if (process.env.NODE_ENV !== "production" || !isUnitEconomicsEnabled()) return;
  const errors = validateUnitEconomicsConfiguration();
  if (errors.length > 0) throw new Error(errors.join(" "));
}
