/**
 * Billing truth — fail closed. Do not imply checkout works when it does not.
 */

import {
  getPaymentStackAudit,
  isLiveBillingAvailable,
  type PaymentStackAudit,
} from "@/lib/entitlement/payment-stack";

export function isBillingEnabled(): boolean {
  return isLiveBillingAvailable();
}

export function checkoutImplemented(): boolean {
  return getPaymentStackAudit().checkoutImplemented;
}

export function billingPortalImplemented(): boolean {
  return getPaymentStackAudit().billingPortalImplemented;
}

export function getBillingAudit(): PaymentStackAudit {
  return getPaymentStackAudit();
}

/** Pro preview allowed only in development or explicit founder debug flag. */
export function isProPreviewAllowed(): boolean {
  if (typeof window === "undefined") {
    return process.env.NODE_ENV !== "production";
  }
  if (isBillingEnabled()) return false;
  if (process.env.NODE_ENV !== "production") return true;
  try {
    return localStorage.getItem("voicememory_founder_pro_preview") === "1";
  } catch {
    return false;
  }
}

export type EntitlementSource = "free_tier" | "paid" | "preview" | "denied";

export function resolveEntitlementSource(
  tier: "free" | "pro",
  entitlementGranted: boolean,
): EntitlementSource {
  if (!entitlementGranted) return "denied";
  if (tier === "free") return "free_tier";
  if (isBillingEnabled()) return "paid";
  if (isProPreviewAllowed()) return "preview";
  return "denied";
}
