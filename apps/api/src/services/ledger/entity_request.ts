const minLabelLength = 3;
const maxLabelLength = 80;

/// A label long enough to match ledger text without wiping short words.
export function ledgerLabelPattern(label: string): string | null {
  const trimmed = label.trim();
  if (trimmed.length < minLabelLength || trimmed.length > maxLabelLength) {
    return null;
  }
  const escaped = trimmed.replace(/[\\%_]/g, (char) => `\\${char}`);
  return `%${escaped}%`;
}

export function parseLedgerEntityDelete(
  body: unknown,
): { label: string } | null {
  if (!body || typeof body !== "object") return null;
  const label = (body as { label?: unknown }).label;
  if (typeof label !== "string") return null;
  const pattern = ledgerLabelPattern(label);
  if (!pattern) return null;
  return { label: label.trim() };
}
