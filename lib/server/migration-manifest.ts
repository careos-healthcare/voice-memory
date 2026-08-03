/**
 * Required Postgres objects for Grade A production — verified by validate:migrations.
 */

export const REQUIRED_TABLES = [
  "auth_codes",
  "sessions",
  "user_profiles",
  "sync_blobs",
  "sync_recovery_envelopes",
  "api_usage",
  "openai_daily_spend",
  "api_minute_usage",
  "billing_entitlements",
  "revenuecat_user_mappings",
  "billing_entitlement_sources",
  "revenuecat_webhook_events",
  "usage_reservations",
  "capture_attestations",
  "journal_entries",
  "resurfacing_events",
  "resurfacing_feedback",
  "stripe_webhook_events",
  "ue_pricing_versions",
  "ue_price_lines",
  "ue_usage_ledger",
  "ue_daily_subject_rollups",
  "ue_threshold_breaches",
  "account_deletion_requests",
  "account_deletion_outbox",
  "account_deletion_receipts",
] as const;

export const REQUIRED_INDEXES = [
  { table: "auth_codes", index: "auth_codes_expires_at_idx" },
  { table: "sessions", index: "sessions_user_id_idx" },
  { table: "sessions", index: "sessions_expires_at_idx" },
  { table: "sync_blobs", index: "sync_blobs_user_updated_idx" },
  { table: "sync_blobs", index: "sync_blobs_device_idx" },
  {
    table: "sync_recovery_envelopes",
    index: "sync_recovery_envelopes_updated_idx",
  },
  { table: "journal_entries", index: "journal_entries_user_updated_idx" },
  { table: "resurfacing_events", index: "resurfacing_events_subject_created_idx" },
  { table: "resurfacing_feedback", index: "resurfacing_feedback_user_created_idx" },
  { table: "ue_pricing_versions", index: "ue_pricing_versions_effective_from_idx" },
  { table: "ue_usage_ledger", index: "ue_usage_ledger_subject_day_idx" },
  { table: "ue_usage_ledger", index: "ue_usage_ledger_day_category_idx" },
  { table: "ue_usage_ledger", index: "ue_usage_ledger_day_subject_idx" },
  { table: "ue_daily_subject_rollups", index: "ue_daily_subject_rollups_day_idx" },
  { table: "ue_threshold_breaches", index: "ue_threshold_breaches_subject_day_idx" },
  {
    table: "billing_entitlement_sources",
    index: "billing_entitlement_sources_status_idx",
  },
  {
    table: "usage_reservations",
    index: "usage_reservations_allowance_idx",
  },
  {
    table: "account_deletion_requests",
    index: "account_deletion_requests_status_updated_idx",
  },
  {
    table: "account_deletion_outbox",
    index: "account_deletion_outbox_retry_idx",
  },
] as const;

export type RequiredTable = (typeof REQUIRED_TABLES)[number];
