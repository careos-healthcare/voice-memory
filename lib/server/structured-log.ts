/**
 * Structured server logs — never include transcripts or journal body text.
 */

export type LogEvent =
  | "auth_failure"
  | "rate_limit"
  | "billing_webhook"
  | "billing_checkout"
  | "account_deletion"
  | "journal_sync_failure"
  | "health_check"
  | "production_startup";

export function logServerEvent(
  event: LogEvent,
  fields: Record<string, string | number | boolean | null | undefined>,
): void {
  const payload = {
    ts: new Date().toISOString(),
    event,
    ...sanitizeFields(fields),
  };
  console.info("[ArchiveMe]", JSON.stringify(payload));
}

function sanitizeFields(
  fields: Record<string, string | number | boolean | null | undefined>,
): Record<string, string | number | boolean | null> {
  const out: Record<string, string | number | boolean | null> = {};
  const banned = /transcript|journal|payload|audio|reflection|email_body/i;
  for (const [key, value] of Object.entries(fields)) {
    if (banned.test(key)) continue;
    if (typeof value === "string" && value.length > 200) {
      out[key] = `${value.slice(0, 80)}…[truncated]`;
      continue;
    }
    out[key] = value ?? null;
  }
  return out;
}
