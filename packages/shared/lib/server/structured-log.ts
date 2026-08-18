/**
 * Structured server logs — never include transcripts or journal body text.
 */

import { hashUserIdForAudit } from "@/lib/server/auth-crypto";
import {
  REDACTED_LOG_FIELD_NAMES,
  sanitizeLogRecord,
} from "@/lib/server/log-sanitizer";

export type LogEvent =
  | "auth_failure"
  | "rate_limit"
  | "billing_webhook"
  | "billing_checkout"
  | "account_deletion"
  | "user_data_wipe"
  | "journal_sync_failure"
  | "health_check"
  | "production_startup"
  | "api_error";

export function logServerEvent(
  event: LogEvent,
  fields: Record<string, string | number | boolean | null | undefined>,
): void {
  const payload = sanitizeLogRecord({
    ts: new Date().toISOString(),
    event,
    ...fields,
  }) as Record<string, unknown>;
  console.info("[ArchiveMe]", JSON.stringify(payload));
}

export { REDACTED_LOG_FIELD_NAMES, hashUserIdForAudit };
