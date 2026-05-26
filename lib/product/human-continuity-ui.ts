import { getEntryPreviewLine } from "@/lib/reflection";
import type { JournalEntry } from "@/types/journal";
import type { RelatedReflection } from "@/types/memory-continuity";

/** User-facing copy that reads like a mood tracker, not remembered words. */
const SYNTHETIC_LABEL_RE =
  /\b(speaker expresses|the speaker|user expresses|the user feels|they seem to feel|appears to be feeling|mood snapshot|dominant mood|emotional intensity|intensity trend|mood tracker|feels anxious|feels sad|labeled as)\b/i;

type PublicMatchReason = Exclude<
  RelatedReflection["matchReasons"][number],
  "mood"
>;

const PUBLIC_MATCH_REASONS: Record<PublicMatchReason, string> = {
  themes: "Themes",
  entities: "People & topics",
  keywords: "Wording",
  concern: "Concern",
  recommendation: "Next step you named",
};

/** Strip third-person / clinical observation framing from product UI. */
export function sanitizeUserFacingObservation(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  if (SYNTHETIC_LABEL_RE.test(trimmed)) return null;
  return trimmed;
}

/** One-line list preview — quote or observation, never a mood label. */
export function entryContinuitySnippet(entry: JournalEntry, maxLen = 160): string {
  const fromTranscript = entry.transcript?.trim();
  if (fromTranscript) {
    const slice = fromTranscript.slice(0, maxLen);
    return fromTranscript.length > maxLen ? `${slice}…` : slice;
  }
  const observation = sanitizeUserFacingObservation(getEntryPreviewLine(entry.reflection));
  return observation ?? "Voice reflection";
}

/** Match chips for continuity — mood-based matching stays internal only. */
export function publicMatchReasonLabel(
  reason: RelatedReflection["matchReasons"][number],
): string | null {
  if (reason === "mood") return null;
  return PUBLIC_MATCH_REASONS[reason as PublicMatchReason] ?? null;
}
