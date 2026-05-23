import type { JournalEntry } from "@/types/journal";
import type { AvoidanceSignal } from "@/types/pattern-insights";

const VAGUE_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bthat thing\b/gi, label: "that thing" },
  { re: /\bsomething\b/gi, label: "something" },
  { re: /\bsomeone\b/gi, label: "someone" },
  { re: /\bthat situation\b/gi, label: "that situation" },
  { re: /\bthis stuff\b/gi, label: "this stuff" },
  { re: /\bwhatever\b/gi, label: "whatever" },
];

const HEDGING_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bmaybe\b/gi, label: "maybe" },
  { re: /\bkind of\b/gi, label: "kind of" },
  { re: /\bsort of\b/gi, label: "sort of" },
  { re: /\bi guess\b/gi, label: "I guess" },
  { re: /\bprobably\b/gi, label: "probably" },
  { re: /\bnot sure\b/gi, label: "not sure" },
  { re: /\bi don'?t know\b/gi, label: "I don't know" },
];

const INDIRECT_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bthey\b/gi, label: "they (unnamed)" },
  { re: /\bthat person\b/gi, label: "that person" },
  { re: /\bthe situation\b/gi, label: "the situation" },
  { re: /\bover there\b/gi, label: "over there" },
];

const STRESS_WITHOUT_NAME =
  /\b(stressed|anxious|worried|overwhelmed|tense|pressure|heavy|hard)\b/gi;

function hasNamedEntity(text: string): boolean {
  return /\b[A-Z][a-z]{2,}\b/.test(text) || /\bmy (mom|dad|partner|boss|friend|team)\b/i.test(text);
}

export function detectAvoidanceSignals(entry: JournalEntry): AvoidanceSignal[] {
  const text = entry.transcript;
  const results: AvoidanceSignal[] = [];

  for (const { re, label } of VAGUE_PATTERNS) {
    const hits = text.match(re);
    if (hits && hits.length > 0) {
      results.push({
        id: `vague-${label}`,
        kind: "vague_reference",
        label: `Vague reference: "${label}"`,
        detail: `You use "${label}" without naming the specific person, place, or topic — indirect language that may mark an unnamed stressor.`,
      });
    }
  }

  for (const { re, label } of INDIRECT_PATTERNS) {
    const hits = text.match(re);
    if (hits && hits.length >= 2) {
      results.push({
        id: `indirect-${label}`,
        kind: "indirect_reference",
        label: `Indirect reference: ${label}`,
        detail: `Repeated indirect wording ("${label}") — the subject stays off-record even while you describe the feeling around it.`,
      });
    }
  }

  const hedges = HEDGING_PATTERNS.flatMap(({ re, label }) => {
    const count = (text.match(re) ?? []).length;
    return count >= 2 ? [label] : [];
  });

  if (hedges.length > 0) {
    results.push({
      id: "hedging",
      kind: "emotional_hedging",
      label: "Emotional hedging",
      detail: `Hedging language appears repeatedly (${hedges.join(", ")}) — you soften or defer certainty while still circling the topic.`,
    });
  }

  const stressHits = text.match(STRESS_WITHOUT_NAME);
  if (stressHits && stressHits.length >= 2 && !hasNamedEntity(text)) {
    results.push({
      id: "unnamed-stressor",
      kind: "unnamed_stressor",
      label: "Stress without a named source",
      detail: "You describe pressure or tension more than once without naming who, what, or where — the stressor stays implicit in your words.",
    });
  }

  return results.slice(0, 5);
}
