import type { JournalEntry } from "@/types/journal";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const PLACEHOLDER_RE =
  /^(YOUR_|PLACEHOLDER|TEMPLATE|EXAMPLE_|SAMPLE_|INSERT_|REPLACE_|TODO_)/i;

/** Normalize dynamic route param to a single trimmed id string. */
export function normalizeEntryRouteId(
  raw: string | string[] | undefined,
): string {
  if (Array.isArray(raw)) return raw[0]?.trim() ?? "";
  return typeof raw === "string" ? raw.trim() : "";
}

/** Marketing/docs placeholder ids — never run presentation builders for these. */
export function isPlaceholderEntryId(id: string): boolean {
  if (!id) return true;
  if (PLACEHOLDER_RE.test(id)) return true;
  if (/YOUR_/i.test(id) || /PLACEHOLDER/i.test(id)) return true;
  if (/^<[^>]+>$/.test(id)) return true;
  return false;
}

/** Stored reflections use UUIDs (or stress-test ids). */
export function isLikelyStoredEntryId(id: string): boolean {
  if (!id) return false;
  if (UUID_RE.test(id)) return true;
  if (/^stress-entry-/i.test(id)) return true;
  return false;
}

export function isInvalidEntryRouteId(id: string): boolean {
  if (!id) return true;
  if (isPlaceholderEntryId(id)) return true;
  return !isLikelyStoredEntryId(id);
}

export function shouldRunEntryPresentationBuilders(
  entryId: string,
  entry: JournalEntry | undefined,
  options: { loading: boolean },
): boolean {
  if (options.loading) return false;
  if (isInvalidEntryRouteId(entryId)) return false;
  if (!entry) return false;
  return true;
}
