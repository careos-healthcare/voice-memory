import {
  trackConversionReason,
  trackPaywallInterestReason,
  trackPaywallRejectionReason,
} from "@/lib/metrics/paywall-attribution-events";
import {
  CONVERSION_REASON_LABELS,
  PAYWALL_INTEREST_LABELS,
  PAYWALL_REJECTION_LABELS,
} from "@/lib/billing/paywall-attribution-copy";
import { getPlanId } from "@/lib/subscription";
import type {
  ConversionReasonId,
  PaywallAttributionKind,
  PaywallAttributionRecord,
  PaywallInterestReasonId,
  PaywallRejectionReasonId,
} from "@/types/paywall-attribution";

export const PAYWALL_ATTRIBUTION_RECORDS_KEY = "voicememory_paywall_attribution_records";
export const PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY =
  "voicememory_paywall_attribution_pending_conversion";
export const PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY =
  "voicememory_paywall_attribution_conversion_answered";

const MAX_RECORDS = 300;

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function readRecords(): PaywallAttributionRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(PAYWALL_ATTRIBUTION_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as PaywallAttributionRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(rows: PaywallAttributionRecord[]): void {
  getStorage()?.setItem(
    PAYWALL_ATTRIBUTION_RECORDS_KEY,
    JSON.stringify(rows.slice(-MAX_RECORDS)),
  );
}

function appendRecord(
  kind: PaywallAttributionKind,
  reason: string,
  meta?: { source?: string; surface?: string },
): PaywallAttributionRecord {
  const record: PaywallAttributionRecord = {
    id: newId("pa"),
    kind,
    reason,
    at: new Date().toISOString(),
    source: meta?.source,
    surface: meta?.surface,
  };
  const rows = readRecords();
  rows.push(record);
  writeRecords(rows);
  return record;
}

export function savePaywallRejectionReason(
  reason: PaywallRejectionReasonId,
  meta?: { surface?: string; source?: string },
): PaywallAttributionRecord {
  const record = appendRecord("rejection", reason, meta);
  trackPaywallRejectionReason({
    reason,
    attributionId: record.id,
    surface: meta?.surface,
    source: meta?.source,
  });
  return record;
}

export function savePaywallInterestReason(
  reason: PaywallInterestReasonId,
  meta?: { surface?: string; source?: string },
): PaywallAttributionRecord {
  const record = appendRecord("interest", reason, meta);
  trackPaywallInterestReason({
    reason,
    attributionId: record.id,
    surface: meta?.surface,
    source: meta?.source,
  });
  return record;
}

export function saveConversionReason(
  reason: ConversionReasonId,
  meta?: { source?: string },
): PaywallAttributionRecord {
  const record = appendRecord("conversion", reason, meta);
  trackConversionReason({
    reason,
    attributionId: record.id,
    source: meta?.source,
  });
  getStorage()?.setItem(PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY, "1");
  getStorage()?.removeItem(PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY);
  return record;
}

export function armConversionReasonPrompt(source?: string): void {
  const store = getStorage();
  if (!store) return;
  if (store.getItem(PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY)) return;
  store.setItem(
    PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY,
    JSON.stringify({ source: source ?? "checkout_success", armedAt: new Date().toISOString() }),
  );
}

export function shouldShowConversionReasonPrompt(): boolean {
  const store = getStorage();
  if (!store) return false;
  if (store.getItem(PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY)) return false;
  if (!store.getItem(PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY)) return false;
  return getPlanId() === "pro";
}

export function dismissConversionReasonPrompt(): void {
  getStorage()?.removeItem(PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY);
  getStorage()?.setItem(PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY, "1");
}

export function readPaywallAttributionRecords(): PaywallAttributionRecord[] {
  return readRecords().slice().reverse();
}

export function rejectionLabel(reason: PaywallRejectionReasonId): string {
  return PAYWALL_REJECTION_LABELS[reason];
}

export function interestLabel(reason: PaywallInterestReasonId): string {
  return PAYWALL_INTEREST_LABELS[reason];
}

export function conversionLabel(reason: ConversionReasonId): string {
  return CONVERSION_REASON_LABELS[reason];
}

export function clearPaywallAttributionForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(PAYWALL_ATTRIBUTION_RECORDS_KEY);
  store.removeItem(PAYWALL_ATTRIBUTION_PENDING_CONVERSION_KEY);
  store.removeItem(PAYWALL_ATTRIBUTION_CONVERSION_ANSWERED_KEY);
}
