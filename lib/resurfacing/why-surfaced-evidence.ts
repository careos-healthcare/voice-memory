import type { ResurfacingEvidence } from "@/types/resurfacing-evidence";

/** Human-readable “why this surfaced” from evidence only — no therapy or EI claims. */
export function formatWhySurfacedFromEvidence(
  evidence: ResurfacingEvidence,
  cautious: boolean,
): string {
  const parts: string[] = [];

  if (evidence.exactQuoteMatches[0]) {
    const q = evidence.exactQuoteMatches[0];
    const short = q.length > 48 ? `${q.slice(0, 45)}…` : q;
    parts.push(`you used “${short}” in your words`);
  } else if (evidence.repeatedPhrases[0]) {
    const p = evidence.repeatedPhrases[0];
    const short = p.length > 40 ? `${p.slice(0, 37)}…` : p;
    parts.push(`you used “${short}” more than once`);
  }

  if (evidence.sharedPeople.length > 0) {
    const who = evidence.sharedPeople.slice(0, 2).join(" and ");
    parts.push(`both entries mention ${who}`);
  }
  if (evidence.sharedTopics.length > 0) {
    const topic = evidence.sharedTopics[0];
    parts.push(`the same topic (${topic}) came up again`);
  }
  if (evidence.sharedTimeWindow) {
    parts.push(evidence.sharedTimeWindow);
  }
  if (evidence.emotionalShift) {
    parts.push(evidence.emotionalShift);
  }
  if (evidence.contradictionSignal && evidence.emotionalShift) {
    /* change line already in emotionalShift */
  } else if (evidence.contradictionSignal) {
    parts.push("these entries pull in different directions");
  }

  if (parts.length === 0) {
    return cautious
      ? "This might connect — we only have a loose link between these entries."
      : "A concrete link between your entries surfaced this.";
  }

  const joined = parts.slice(0, 3).join(", and ");
  if (cautious || evidence.cautiousWordingRequired) {
    return `This might be connected because ${joined}.`;
  }
  return `This surfaced because ${joined}.`;
}
