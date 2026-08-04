import {
  isUnitEconomicsEnabled,
  isUnitEconomicsPricingRequired,
  validateUnitEconomicsConfiguration,
} from "@/lib/server/unit-economics-config";
import { pricingCoverageErrors } from "@/lib/server/unit-economics-pricing-catalog";
import { selectPricingCatalog } from "@/lib/server/unit-economics-pricing-store";

export interface UnitEconomicsReadiness {
  ready: boolean;
  enabled: boolean;
  pricingRequired: boolean;
  codes: string[];
  activePricingVersion: string | null;
}

export async function getUnitEconomicsReadiness(
  now = new Date(),
): Promise<UnitEconomicsReadiness> {
  const enabled = isUnitEconomicsEnabled();
  if (!enabled) {
    return {
      ready: true,
      enabled: false,
      pricingRequired: false,
      codes: [],
      activePricingVersion: null,
    };
  }
  const codes = validateUnitEconomicsConfiguration().map(
    () => "CONFIGURATION_INVALID",
  );
  let pricingRequired = true;
  try {
    pricingRequired = isUnitEconomicsPricingRequired();
  } catch {
    codes.push("PRICING_CONFIGURATION_INVALID");
  }
  let activePricingVersion: string | null = null;
  if (pricingRequired && codes.length === 0) {
    try {
      const catalog = await selectPricingCatalog(now);
      if (!catalog) {
        codes.push("ACTIVE_PRICING_CATALOG_MISSING");
      } else {
        activePricingVersion = catalog.versionKey;
        if (pricingCoverageErrors(catalog.lines).length > 0) {
          codes.push("ACTIVE_PRICING_COVERAGE_INCOMPLETE");
        }
      }
    } catch {
      codes.push("ACTIVE_PRICING_CHECK_FAILED");
    }
  }
  return {
    ready: codes.length === 0,
    enabled,
    pricingRequired,
    codes: [...new Set(codes)],
    activePricingVersion,
  };
}
