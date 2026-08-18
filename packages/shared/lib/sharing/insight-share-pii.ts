const EMAIL_RE = /[\w.+-]+@[\w.-]+\.\w{2,}/gi;
const PHONE_RE =
  /\b(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?){2}\d{4}\b/g;
const URL_RE = /https?:\/\/\S+/gi;
const HANDLE_RE = /@[\w.-]+/g;
const SSN_RE = /\b\d{3}-\d{2}-\d{4}\b/g;
const CARD_RE = /\b(?:\d[ -]*?){13,16}\b/g;

const REDACTED = "[redacted]";

/** Removes common PII patterns from text destined for share sheets or cards. */
export function stripInsightSharePii(text: string): string {
  let result = text.trim();
  if (!result) return "";

  result = result.replace(EMAIL_RE, REDACTED);
  result = result.replace(PHONE_RE, REDACTED);
  result = result.replace(URL_RE, REDACTED);
  result = result.replace(HANDLE_RE, REDACTED);
  result = result.replace(SSN_RE, REDACTED);
  result = result.replace(CARD_RE, REDACTED);
  result = result.replace(/(\[redacted\]\s*){2,}/gi, `${REDACTED} `);
  result = result.replace(/\s+/g, " ").trim();

  if (result === REDACTED || result.replaceAll(REDACTED, "").trim().length === 0) {
    return "";
  }

  return result;
}

/** Sanitizes each line; drops lines that become empty after redaction. */
export function sanitizeInsightShareLines(lines: string[]): string[] {
  const cleaned: string[] = [];
  for (const line of lines) {
    const sanitized = stripInsightSharePii(line);
    if (sanitized) cleaned.push(sanitized);
  }
  return cleaned;
}
