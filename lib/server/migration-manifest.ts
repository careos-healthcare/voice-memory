/**
 * Required Postgres objects for Grade A production — verified by validate:migrations.
 */

export const REQUIRED_TABLES = [
  "auth_codes",
  "sessions",
  "sync_blobs",
  "api_usage",
  "openai_daily_spend",
  "api_minute_usage",
  "billing_entitlements",
  "capture_attestations",
  "journal_entries",
  "resurfacing_events",
  "resurfacing_feedback",
  "stripe_webhook_events",
  "mobile_push_devices",
] as const;

export const REQUIRED_INDEXES = [
  { table: "auth_codes", index: "auth_codes_expires_at_idx" },
  { table: "sessions", index: "sessions_user_id_idx" },
  { table: "sessions", index: "sessions_expires_at_idx" },
  { table: "sync_blobs", index: "sync_blobs_user_updated_idx" },
  { table: "journal_entries", index: "journal_entries_user_updated_idx" },
  { table: "resurfacing_events", index: "resurfacing_events_subject_created_idx" },
  { table: "resurfacing_feedback", index: "resurfacing_feedback_user_created_idx" },
] as const;

export type RequiredTable = (typeof REQUIRED_TABLES)[number];
