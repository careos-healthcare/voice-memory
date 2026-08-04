import {
  archiveMeMonetizationPolicy,
  capabilityById,
  type CapabilityId,
  type MonetizationCapability as GeneratedMonetizationCapability,
  type UsageMeterId as GeneratedUsageMeterId,
} from "@/lib/monetization/generated/archiveMeMonetizationPolicy";

type RawPolicy = typeof archiveMeMonetizationPolicy;

export type MonetizationPlanId = RawPolicy["plans"][number]["id"];
export type MonetizationPlanKind = RawPolicy["plans"][number]["kind"];
export type MonetizationCapabilityId = CapabilityId;
export type UsageMeterId = GeneratedUsageMeterId;
export type UsageMeterUnit = RawPolicy["usageMeters"][number]["unit"];

export type MonetizationCapability = GeneratedMonetizationCapability;

export const MONETIZATION_POLICY_VERSION =
  archiveMeMonetizationPolicy.policyVersion;
export const CANONICAL_REVENUECAT_PRO_ENTITLEMENT_ID =
  archiveMeMonetizationPolicy.revenueCat.canonicalProEntitlementId;
export const REVENUECAT_PRO_ENTITLEMENT_IDS = [
  CANONICAL_REVENUECAT_PRO_ENTITLEMENT_ID,
  ...archiveMeMonetizationPolicy.revenueCat.acceptedLegacyEntitlementAliases,
] as const;
export const REVENUECAT_LEGACY_GRANDFATHERED_PRODUCT_IDS =
  archiveMeMonetizationPolicy.revenueCat.legacyGrandfatheredProductIds;

export const MONETIZATION_PLAN_IDS = archiveMeMonetizationPolicy.plans.map(
  (plan) => plan.id,
);
export const USAGE_METER_IDS = archiveMeMonetizationPolicy.usageMeters.map(
  (meter) => meter.id,
);

export function getMonetizationCapability(
  id: MonetizationCapabilityId,
): MonetizationCapability {
  const capability = capabilityById[id];
  if (!capability) throw new Error("MONETIZATION_CAPABILITY_UNKNOWN");
  return capability;
}

export function getUsageMeter(id: UsageMeterId) {
  const meter = archiveMeMonetizationPolicy.usageMeters.find(
    (candidate) => candidate.id === id,
  );
  if (!meter) throw new Error("MONETIZATION_USAGE_METER_UNKNOWN");
  return meter;
}

export function isMonetizationPlanId(value: unknown): value is MonetizationPlanId {
  return typeof value === "string" &&
    MONETIZATION_PLAN_IDS.some((candidate) => candidate === value);
}

export function isUsageMeterId(value: unknown): value is UsageMeterId {
  return typeof value === "string" &&
    USAGE_METER_IDS.some((candidate) => candidate === value);
}
