import { CLARITY_AFTER_SAVE_LINES } from "@/lib/clarity/clarity-copy";
import { detectThinkingOutLoudSignals } from "@/lib/clarity/thinking-out-loud-signals";
import type { ThinkingOutLoudSignals } from "@/types/clarity";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { JournalEntry } from "@/types/journal";

const AVOIDED_RE =
  /\b(avoided saying|didn'?t say|wanted to say|wish i said|finally said)\b/i;
const ASSUME_RE = /\b(assumed|i thought they|i thought he|i thought she)\b/i;
const UNRESOLVED_RE =
  /\b(still (?:feel|feels) unresolved|not resolved|don'?t know if|what happened was)\b/i;
const CHANGED_RE = /\b(changed|different now|not the same|since then|now i)\b/i;
const HAPPENED_MEANING_RE =
  /\b(what happened|it meant|happened was|i felt|but i)\b/i;

function priorSignals(entry: JournalEntry | undefined): ThinkingOutLoudSignals | null {
  if (!entry?.transcript?.trim()) return null;
  return detectThinkingOutLoudSignals(entry.transcript);
}

/** At most one after-save line — only when transcript supports it. */
export function pickAfterSaveClarityLine(
  priorEntry: JournalEntry | undefined,
  newEntry: JournalEntry,
  clarityContext: ClarityRecordContext | null,
): string | null {
  const next = newEntry.transcript.trim();
  if (next.length < 24) return null;

  const priorText = priorEntry?.transcript?.trim() ?? "";
  const before = priorSignals(priorEntry);
  const after = detectThinkingOutLoudSignals(next);

  if (clarityContext?.promptKey === "what_avoided" || (before?.avoidedSpeechLikely && AVOIDED_RE.test(next))) {
    if (AVOIDED_RE.test(next) && (!priorText || !AVOIDED_RE.test(priorText))) {
      return CLARITY_AFTER_SAVE_LINES.saidWhatAvoided;
    }
  }

  if (
    UNRESOLVED_RE.test(next) &&
    (before?.uncertaintyLikely || clarityContext?.promptKey === "what_unresolved")
  ) {
    return CLARITY_AFTER_SAVE_LINES.returnedUnresolved;
  }

  if (
    HAPPENED_MEANING_RE.test(next) &&
    ASSUME_RE.test(next) &&
    (before?.conflictLikely || after.conflictLikely)
  ) {
    return CLARITY_AFTER_SAVE_LINES.separatedHappenedFromMeaning;
  }

  if (
    CHANGED_RE.test(next) &&
    priorText.length > 20 &&
    (clarityContext?.promptKey === "what_changed" || after.repeatedThoughtLikely)
  ) {
    return CLARITY_AFTER_SAVE_LINES.changedInOwnWords;
  }

  return null;
}
