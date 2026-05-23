import type {
  FollowupCandidate,
  FollowupPrompt,
  FollowupSource,
} from "@/types/followup-prompt";
import type { MemoryNote } from "@/types/memory-note";

export const FOLLOWUP_PROMPT_KEY = "voicememory_followup_prompt";

const STRONG_MIN = 62;
const EVIDENCE_MIN = 64;

const BANNED_PROMPT_RE =
  /\b(analysis|insight|therapy|coach|should|try to|recommend|diagnos|assistant)\b/i;

const SOURCE_PRIORITY: Record<FollowupSource, number> = {
  then_vs_now: 100,
  recovery: 92,
  continuity: 88,
  resurfacing: 84,
  familiarity_resurfacing: 80,
  revisitation: 76,
};

const DEFAULT_PROMPTS: Record<FollowupSource, string> = {
  then_vs_now: "What changed between then and now?",
  recovery: "What feels different now?",
  continuity: "Do you want to say more about this?",
  resurfacing: "Does this still feel true?",
  familiarity_resurfacing: "What feels different now?",
  revisitation: "Did this resolve or return?",
};

function isRecoveryNote(note: MemoryNote): boolean {
  return (
    note.id.startsWith("recovery-") ||
    note.id.startsWith("moment-recovery-") ||
    /\b(recovery|calmer|quieter|resolved)\b/i.test(note.text)
  );
}

/** Classify whether a visible memory note qualifies for a follow-up prompt. */
export function classifyFollowupSource(note: MemoryNote): FollowupSource | null {
  if (note.id.startsWith("tvn-")) return "then_vs_now";
  if (note.id.startsWith("continuity-")) return "continuity";
  if (note.id.startsWith("resurface-")) return "resurfacing";
  if (note.id.startsWith("revisit-")) return "revisitation";
  if (note.id.startsWith("fam-resurface-")) return "familiarity_resurfacing";
  if (isRecoveryNote(note)) return "recovery";

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    return "then_vs_now";
  }

  return null;
}

function hasStrongEvidence(note: MemoryNote): boolean {
  const hasQuotes = Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
  const hasDates = Boolean(note.pastDateLabel && note.currentDateLabel);
  if (hasQuotes) return true;
  if (hasDates && note.confidence >= EVIDENCE_MIN) return true;
  if (note.text.trim().length >= 24 && note.confidence >= EVIDENCE_MIN) return true;
  return false;
}

function isEligibleNote(note: MemoryNote): boolean {
  if (note.confidence < STRONG_MIN) return false;
  if (!hasStrongEvidence(note)) return false;
  return classifyFollowupSource(note) !== null;
}

function promptForSource(note: MemoryNote, source: FollowupSource): string {
  const text = note.text.toLowerCase();

  if (source === "then_vs_now" || (note.pastQuote && note.currentQuote)) {
    return "What changed between then and now?";
  }

  if (
    source === "continuity" ||
    /\b(continuation|came back|returned|unresolved|left this)\b/i.test(text)
  ) {
    if (/\b(unresolved|left this)\b/i.test(text)) {
      return "Did this resolve or return?";
    }
    if (/\b(different|changed|differently)\b/i.test(text)) {
      return "What feels different now?";
    }
    return "Do you want to say more about this?";
  }

  if (source === "recovery" || /\b(calmer|quieter|recovery|resolved)\b/i.test(text)) {
    return "What feels different now?";
  }

  if (/\b(return|came back|again|revisit)\b/i.test(text)) {
    return "Did this resolve or return?";
  }

  if (/\b(different|changed|read differently|sound different)\b/i.test(text)) {
    return "What feels different now?";
  }

  if (/\b(familiar|before|then|now|older)\b/i.test(text)) {
    return "Does this still feel true?";
  }

  return DEFAULT_PROMPTS[source];
}

function scoreCandidate(candidate: FollowupCandidate): number {
  return candidate.priority + candidate.note.confidence;
}

/** Build follow-up candidates from visible memory notes. */
export function gatherFollowupCandidates(notes: MemoryNote[]): FollowupCandidate[] {
  const candidates: FollowupCandidate[] = [];

  for (const note of notes) {
    if (!isEligibleNote(note)) continue;
    const source = classifyFollowupSource(note);
    if (!source) continue;

    candidates.push({
      note,
      source,
      priority: SOURCE_PRIORITY[source],
    });
  }

  return candidates;
}

/** Pick at most one grounded follow-up prompt for a page. */
export function buildFollowupPrompt(notes: MemoryNote[]): FollowupPrompt | null {
  const candidates = gatherFollowupCandidates(notes);

  if (candidates.length === 0) return null;

  const best = [...candidates].sort((a, b) => scoreCandidate(b) - scoreCandidate(a))[0];
  const text = promptForSource(best.note, best.source).trim();

  if (text.length < 12 || BANNED_PROMPT_RE.test(text)) return null;

  return {
    id: `followup-${best.source}-${best.note.id}`,
    text,
    source: best.source,
    noteId: best.note.id,
    noteText: best.note.text,
    strength: scoreCandidate(best),
  };
}

export function storeFollowupPrompt(text: string): void {
  if (typeof window === "undefined") return;
  sessionStorage.setItem(FOLLOWUP_PROMPT_KEY, text);
}

export function consumeStoredFollowupPrompt(): string | null {
  if (typeof window === "undefined") return null;
  const text = sessionStorage.getItem(FOLLOWUP_PROMPT_KEY);
  if (text) sessionStorage.removeItem(FOLLOWUP_PROMPT_KEY);
  return text;
}
