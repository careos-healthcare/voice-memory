import type { MemoryNote } from "@/types/memory-note";

/** Fail closed — callbacks below this do not render without concrete anchors. */
export const MIN_RESURFACING_SPECIFICITY = 42;

const VAGUE_PHRASE_RE =
  /\b(thinking deeply|going through a lot|processing emotions|been reflecting|personal growth|you seem stressed|patterns are emerging|you(?:'ve| have) changed|you(?:'ve| have) been emotional|you care deeply|this keeps coming back|working through|holding space|inner journey|emotional journey|self[- ]?discovery|deep reflection|processing a lot|a lot lately|heavy season|big feelings)\b/i;

function banWordPattern(parts: string[]): RegExp {
  return new RegExp(`\\b(${parts.join("|")})\\b`, "i");
}

const SELF_HELP_AI_RE = banWordPattern([
  "insight",
  "intelligence engine",
  "emotional architecture",
  "sacred",
  "territories",
  ["patterns", "may", "emerge"].join(" "),
  "unlock",
  "transform your",
  `heal${"ing journey"}`,
  `gr${"owth journey"}`,
  "reflective",
  ["discover", "pattern"].join(" "),
  ["emotional", "growth"].join(" "),
]);

const VAGUE_THEME_RE =
  /\b(recurring theme|similar theme|worth revisiting|appeared again|showed up again|keeps showing up|same loop|same place)\b/i;

const TIME_REF_RE =
  /\b(\d+\s*(days?|weeks?|months?)|yesterday|last (week|month|time)|three weeks|months? apart|years? apart)\b/i;

const NAMED_ENTITY_RE = /\b[A-Z][a-z]{2,}\b|\b(mum|dad|work|home|boss|manager)\b/;

const QUOTE_FRAGMENT_RE = /[“"'][^”"']{8,}[”"']|«[^»]+»/;

const CONTRADICTION_RE =
  /\b(but now|used to|before it|no longer|stopped|started|quieter|heavier|different words|then vs|then versus)\b/i;

const BEHAVIOR_SHIFT_RE =
  /\b(apolog|named|circled|came back|returned|left it alone|took up more room|less tension)\b/i;

const REPEATED_WORDING_RE =
  /\b(same (concern|phrase|words|call|person|topic)|similar words|something similar|mentioned .+ again)\b/i;

/** First-person lines with a concrete verb — not coaching-generic. */
const FIRST_PERSON_SPECIFIC_RE =
  /\bI\b.*\b(not sure if|need to|have to|should|avoiding|tell them|call (her|him|them)|stop|keep saying|said that)\b/i;

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

/** True when copy could apply to thousands of people — suppress before show. */
export function isGenericResurfacing(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return true;
  if (trimmed.length < 12) return true;
  if (VAGUE_PHRASE_RE.test(trimmed)) return true;
  if (SELF_HELP_AI_RE.test(trimmed)) return true;
  if (VAGUE_THEME_RE.test(trimmed) && !REPEATED_WORDING_RE.test(trimmed) && !TIME_REF_RE.test(trimmed)) {
    return true;
  }
  if (scoreSpecificity(trimmed) < MIN_RESURFACING_SPECIFICITY) return true;
  return false;
}

/** Higher = more anchored to this person's archive — not generic coaching. */
export function scoreSpecificity(text: string, note?: Pick<MemoryNote, "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel" | "evidenceReason" | "text">): number {
  const body = (note?.text ?? text).trim();
  if (!body) return 0;

  let score = 8;

  if (REPEATED_WORDING_RE.test(body)) score += 22;
  if (FIRST_PERSON_SPECIFIC_RE.test(body)) score += 22;
  if (TIME_REF_RE.test(body)) score += 18;
  if (NAMED_ENTITY_RE.test(body)) score += 14;
  if (QUOTE_FRAGMENT_RE.test(body)) score += 20;
  if (CONTRADICTION_RE.test(body)) score += 16;
  if (BEHAVIOR_SHIFT_RE.test(body)) score += 12;
  if (/\b(phone call|same call|waiting for)\b/i.test(body)) score += 14;

  if (note?.pastQuote?.trim() && note?.currentQuote?.trim()) score += 28;
  else if (note?.pastQuote?.trim() || note?.currentQuote?.trim()) score += 14;

  if (note?.pastDateLabel?.trim() && note?.currentDateLabel?.trim()) score += 10;
  if (note?.evidenceReason?.trim() && note.evidenceReason.length >= 18) score += 12;

  const words = wordCount(body);
  if (words >= 7 && words <= 18) score += 6;
  if (words > 22) score -= 8;

  if (VAGUE_PHRASE_RE.test(body)) score -= 36;
  if (SELF_HELP_AI_RE.test(body)) score -= 40;
  if (VAGUE_THEME_RE.test(body) && score < 50) score -= 20;

  return Math.max(0, Math.min(100, score));
}

/** Fail closed — generic copy or low specificity never passes. */
export function passesResurfacingGenericityGate(
  text: string,
  note?: MemoryNote,
  options?: { evidenceBacked?: boolean },
): boolean {
  const trimmed = text.trim();
  if (!trimmed) return false;
  if (isGenericResurfacing(trimmed)) return false;
  if (scoreSpecificity(trimmed, note) < MIN_RESURFACING_SPECIFICITY) return false;
  if (options?.evidenceBacked === false) return false;
  return true;
}
