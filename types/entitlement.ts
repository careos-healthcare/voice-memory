/** Product tier — one paid tier only (Pro). */
export type TierId = "free" | "pro";

export type EntitlementId =
  | "local_recording"
  | "limited_archive"
  | "basic_resurfacing"
  | "unlimited_archive"
  | "encrypted_backup"
  | "open_loops"
  | "export_reports"
  | "deeper_resurfacing";

export type EntitlementSource = "tier" | "preview" | "billing";

export interface EntitlementRecord {
  id: EntitlementId;
  tier: TierId;
  granted: boolean;
  source: EntitlementSource;
}

export interface TierSnapshot {
  tier: TierId;
  entitlements: EntitlementId[];
  billingConnected: boolean;
  previewMode: boolean;
}
