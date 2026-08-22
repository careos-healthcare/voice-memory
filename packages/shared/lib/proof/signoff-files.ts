import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

export const SPP20_DIR = resolve(
  process.env.SPP20_DIR ?? resolve(process.env.HOME ?? "/Users/chiragpatel", "Desktop/spp20"),
);

export const DEVICE_SIGNOFF_PATH = resolve(SPP20_DIR, "device_proof_signoff.json");
export const STAGING_STATUS_PATH = resolve(SPP20_DIR, "staging_proof_status.json");
export const BILLING_STATUS_PATH = resolve(SPP20_DIR, "live_billing_proof_status.json");
export const EMAIL_STATUS_PATH = resolve(SPP20_DIR, "email_delivery_proof_status.json");
export const STRIPE_WEBHOOK_STATUS_PATH = resolve(
  SPP20_DIR,
  "stripe_webhook_proof_status.json",
);

export const MAX_SIGNOFF_AGE_MS = 30 * 24 * 60 * 60 * 1000;

export function readJsonFile(path: string): Record<string, unknown> | null {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function isFreshIsoDate(iso: unknown, maxAgeMs = MAX_SIGNOFF_AGE_MS): boolean {
  if (typeof iso !== "string" || !iso.trim()) return false;
  const ts = Date.parse(iso);
  if (!Number.isFinite(ts)) return false;
  return Date.now() - ts <= maxAgeMs;
}

export function requireTruthy(obj: Record<string, unknown> | null, keys: string[]): string[] {
  if (!obj) return keys.map((k) => `${k} missing (no status file)`);
  const missing: string[] = [];
  for (const key of keys) {
    if (obj[key] !== true) missing.push(`${key} not verified`);
  }
  return missing;
}
