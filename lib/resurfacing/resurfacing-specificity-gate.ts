import {
  passesResurfacingGenericityGate,
  scoreSpecificity,
  MIN_RESURFACING_SPECIFICITY,
} from "@/lib/resurfacing/genericity-filter";
import { isEmotionallySpecificCopy } from "@/lib/resurfacing/emotional-specificity";
import type { MemoryNote } from "@/types/memory-note";

const ANCHOR_QUOTE_MIN = 10;
const WEAK_OPENER_RE =
  /^(you came back|this still felt|worth revisiting|appeared again|showed up again|similar theme)\b/i;

/** Concrete anchor required — phrase, name, time, or paired quotes. */
export function hasConcreteResurfacingAnchor(note: MemoryNote): boolean {
  const text = note.text.trim();
  if (!text) return false;

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    if (
      note.pastQuote.trim().length >= ANCHOR_QUOTE_MIN &&
      note.currentQuote.trim().length >= ANCHOR_QUOTE_MIN
    ) {
      return true;
    }
  }

  if (note.pastQuote?.trim() && note.pastQuote.trim().length >= ANCHOR_QUOTE_MIN) {
    return true;
  }

  if (/\b(\d+\s*(days?|weeks?)|yesterday|last (week|month)|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i.test(text)) {
    return true;
  }

  if (/\b(mum|dad|work|boss|manager|[A-Z][a-z]{2,})\b/.test(text)) {
    return true;
  }

  if (/\b(same (words|phrase|call)|you said|you named|phone call)\b/i.test(text)) {
    return true;
  }

  if (note.evidenceReason?.trim() && note.evidenceReason.length >= 20) {
    return true;
  }

  return false;
}

export function passesResurfacingSpecificityGate(
  note: MemoryNote,
  options?: { evidenceBacked?: boolean },
): boolean {
  const text = note.text.trim();
  if (!text || !isEmotionallySpecificCopy(text)) return false;
  if (WEAK_OPENER_RE.test(text) && !hasConcreteResurfacingAnchor(note)) return false;
  if (!hasConcreteResurfacingAnchor(note)) return false;
  if (scoreSpecificity(text, note) < MIN_RESURFACING_SPECIFICITY + 6) return false;
  return passesResurfacingGenericityGate(text, note, options);
}
