import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const SYNTHETIC_OPENER_RE =
  /^(you came back|this used to feel|worth revisiting|there is more|more of your|your archive|an older reflection|this has been|appeared again|showed up again)\b/i;

const SYNTHETIC_BODY_RE =
  /\b(may feel|might feel|appears to|seems to|in other words|over time you|journey|insight|pattern intelligence|continuity engine|working through)\b/i;

const PRODUCT_VOICE_RE = /\b(memory assisted|voice memory|reflection loop)\b/i;

function clipQuote(quote: string, max = 72): string {
  const trimmed = quote.trim().replace(/\s+/g, " ");
  if (trimmed.length <= max) return trimmed;
  return `${trimmed.slice(0, max - 1)}…`;
}

export function isSyntheticResurfacingCopy(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return true;
  if (SYNTHETIC_OPENER_RE.test(trimmed)) return true;
  if (SYNTHETIC_BODY_RE.test(trimmed)) return true;
  if (PRODUCT_VOICE_RE.test(trimmed)) return true;
  if (trimmed.split(/\s+/).length > 20) return true;
  return false;
}

export function syntheticVoicePenalty(text: string): number {
  let penalty = 0;
  if (SYNTHETIC_OPENER_RE.test(text)) penalty += 22;
  if (SYNTHETIC_BODY_RE.test(text)) penalty += 18;
  if (PRODUCT_VOICE_RE.test(text)) penalty += 24;
  if (/\b(you came back to this)\b/i.test(text)) penalty += 16;
  if (text.includes(" — ") || text.includes(";")) penalty += 6;
  return penalty;
}

/** Prefer quote-led, shorter lines — less product-template voice. */
export function naturalizeResurfacingNote(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote {
  const text = note.text.trim();
  if (!text) return note;

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    const sim = quoteSimilarity(note.pastQuote, note.currentQuote);
    if (sim >= 0.78) {
      return {
        ...note,
        text: `You said it again: "${clipQuote(note.currentQuote)}".`,
      };
    }
    return {
      ...note,
      text: `Then: "${clipQuote(note.pastQuote)}" — now it reads differently.`,
    };
  }

  if (note.pastQuote?.trim() && isSyntheticResurfacingCopy(text)) {
    return {
      ...note,
      text: `"${clipQuote(note.pastQuote)}" came back.`,
    };
  }

  const linked = linkedEntriesForNote(note, entries);
  if (linked.length >= 2 && isSyntheticResurfacingCopy(text)) {
    const sorted = [...linked].sort(
      (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
    );
    const snippet = sorted[sorted.length - 1].transcript?.trim().slice(0, 80);
    if (snippet && snippet.length >= 16) {
      return {
        ...note,
        text: `This time: "${clipQuote(snippet)}".`,
      };
    }
  }

  if (isSyntheticResurfacingCopy(text)) {
    const shortened = text
      .replace(SYNTHETIC_OPENER_RE, "")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 90);
    if (shortened.length >= 12) {
      return { ...note, text: shortened };
    }
  }

  return note;
}

export function passesNaturalVoiceGate(note: MemoryNote): boolean {
  const text = note.text.trim();
  if (!text) return false;
  return !isSyntheticResurfacingCopy(text);
}
