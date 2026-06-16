/**
 * Evidence redaction — the only text allowed into an evidence packet is
 * text that has passed through here. There is no safe name validator in
 * this codebase, so user-generated text is simply never admitted; this
 * module redacts the residual risk in publisher/system copy (emails,
 * phone numbers, URLs) and normalizes ids.
 */

const EMAIL_PATTERN = /[\w.+-]+@[\w-]+\.[\w.-]+/g;
const PHONE_PATTERN = /(?:\+?\d[\s().-]?){7,15}\d/g;
const URL_PATTERN = /(?:https?:\/\/|www\.)[^\s<>"')]+/gi;

export const REDACTED_MARK = "[redacted]";

/** Strips emails, phone numbers, and URLs from already-safe copy. */
export function redactText(text: string): string {
  return text
    .replace(EMAIL_PATTERN, REDACTED_MARK)
    .replace(URL_PATTERN, REDACTED_MARK)
    .replace(PHONE_PATTERN, REDACTED_MARK)
    .trim();
}

/** True when text still contains an email, phone number, or URL. */
export function containsPrivatePattern(text: string): boolean {
  return (
    new RegExp(EMAIL_PATTERN.source).test(text) ||
    new RegExp(URL_PATTERN.source, "i").test(text) ||
    new RegExp(PHONE_PATTERN.source).test(text)
  );
}

/**
 * Stable-id shape for source refs and analytics values — user text
 * never matches this. Anything else becomes null.
 */
const SAFE_ID_PATTERN = /^[a-z0-9_-]{1,64}$/i;

export function sanitizeSourceRef(ref: string | undefined): string | null {
  if (!ref) return null;
  const trimmed = ref.trim();
  return SAFE_ID_PATTERN.test(trimmed) ? trimmed.toLowerCase() : null;
}

/** Bare domain only — no path, query, credentials, or fragments. */
export function sanitizeDomain(domain: string | undefined): string | null {
  if (!domain) return null;
  const bare = domain
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .split(/[/?#@\s]/)[0];
  return /^[a-z0-9.-]{1,100}$/.test(bare) && bare.includes(".") ? bare : null;
}

/**
 * Public web page titles are publisher content, not user content, but
 * they still pass through redaction and a length cap.
 */
export function sanitizeWebTitle(title: string | undefined): string | null {
  if (!title) return null;
  const redacted = redactText(title);
  if (!redacted) return null;
  return redacted.length > 120 ? `${redacted.slice(0, 120)}…` : redacted;
}
