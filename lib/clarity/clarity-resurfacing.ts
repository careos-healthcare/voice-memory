import { CLARITY_RESURFACE_LINES } from "@/lib/clarity/clarity-copy";
import { displayThoughtPatterns, extractThoughtPatterns } from "@/lib/clarity/thought-patterns";
import { readThoughtPatternsForEntryFromStore } from "@/lib/clarity/clarity-storage";
import { passesResurfacingGenericityGate } from "@/lib/resurfacing/genericity-filter";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MemoryNote } from "@/types/memory-note";
import type { ThoughtPattern, ThoughtPatternKind } from "@/types/clarity";

const KIND_TO_LINE: Partial<Record<ThoughtPatternKind, keyof typeof CLARITY_RESURFACE_LINES>> = {
  repeated_concern: "misunderstood",
  avoided_speech: "avoidedAgain",
  unresolved_question: "questionReturned",
  assumption: "similarAssumption",
};

function patternOverlap(a: string, b: string): boolean {
  const left = new Set(a.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  const right = new Set(b.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  if (left.size === 0 || right.size === 0) return false;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size) >= 0.35;
}

/** Evidence-backed clarity resurfacing — must pass genericity gate. */
export function buildClarityResurfacingNote(
  currentTranscript: string,
  excludeEntryId?: string,
): MemoryNote | null {
  const currentPatterns = displayThoughtPatterns(extractThoughtPatterns(currentTranscript));
  if (currentPatterns.length === 0) return null;

  const entries = getMemoryEligibleEntries().filter((e) => e.id !== excludeEntryId);
  const priorPatterns: ThoughtPattern[] = [];
  for (const entry of entries.slice(-40)) {
    priorPatterns.push(...readThoughtPatternsForEntryFromStore(entry.id));
  }
  if (priorPatterns.length === 0) return null;

  for (const current of currentPatterns) {
    const prior = priorPatterns.find(
      (row) => row.kind === current.kind && patternOverlap(row.quote, current.quote),
    );
    if (!prior) continue;

    const lineKey = KIND_TO_LINE[current.kind];
    if (!lineKey) continue;
    const text = CLARITY_RESURFACE_LINES[lineKey];
    if (!passesResurfacingGenericityGate(text)) continue;

    return {
      id: `clarity-resurface-${current.kind}-${prior.quote.slice(0, 12)}`,
      text,
      category: "returned",
      confidence: 72,
      evidenceReason: current.quote.slice(0, 80),
      pastQuote: prior.quote,
      currentQuote: current.quote,
    };
  }

  return null;
}
