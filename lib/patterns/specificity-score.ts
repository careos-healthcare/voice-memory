import { addDaysToKey, toDayKey } from "@/lib/dates";
import type { PatternInsightType } from "@/lib/patterns/pattern-engine";
import type { JournalEntry } from "@/types/journal";

export type EvidenceSourceKey =
  | "exact_phrase"
  | "recurrence"
  | "related_entries"
  | "cross_week"
  | "contradiction"
  | "entity_grounding"
  | "date_time";

export interface SpecificityEvidence {
  entryId: string;
  dateLabel?: string;
  phrase: string;
}

export interface SpecificityScoreInput {
  type: PatternInsightType;
  title: string;
  detail: string;
  evidence: SpecificityEvidence[];
  entryIds: string[];
  recurrenceCount: number;
  entriesById?: Map<string, JournalEntry>;
}

export interface SpecificityScoreResult {
  specificityScore: number;
  evidenceCount: number;
  whyThisFeltSpecific: string[];
  evidenceSources: EvidenceSourceKey[];
  isWeakOrGeneric: boolean;
  warnings: string[];
}

const GENERIC_PHRASES = [
  /\byou seem\b/i,
  /\bmight be feeling\b/i,
  /\bconsider trying\b/i,
  /\bbe kind to yourself\b/i,
  /\bhold space\b/i,
  /\bgeneral stress\b/i,
  /\boverall mood\b/i,
  /\bpattern in your (?:words|language)\b/i,
  /\bobserved from your words\b/i,
  /\bnot a diagnosis\b/i,
  /\bnot a clinical\b/i,
  /\brecurring emotional context\b/i,
  /\blanguage pattern observation only\b/i,
  /\bpattern observation only\b/i,
  /\bfrom your words only\b/i,
  /\bemotional shift around\b/i,
  /\bthere may be tension\b/i,
];

const DAY_TIME_RE =
  /\b(sunday|monday|tuesday|wednesday|thursday|friday|saturday|evening|morning|afternoon|week|last 7 days|last 30 days)\b/i;

function weekKeyForEntry(entry: JournalEntry): string {
  const day = toDayKey(entry.createdAt);
  return addDaysToKey(day, -((new Date(entry.createdAt).getDay() + 6) % 7));
}

function countExactPhrases(evidence: SpecificityEvidence[]): number {
  return evidence.filter((e) => {
    const phrase = e.phrase.trim();
    return phrase.length >= 12 || /"[^"]{3,}"/.test(phrase) || phrase.includes("…");
  }).length;
}

/** Score how specific and evidence-grounded an insight is. */
export function scoreInsightSpecificity(
  input: SpecificityScoreInput,
): SpecificityScoreResult {
  const { type, title, detail, evidence, entryIds, recurrenceCount, entriesById } =
    input;
  const text = `${title} ${detail}`;

  let score = 0;
  const whyThisFeltSpecific: string[] = [];
  const evidenceSources: EvidenceSourceKey[] = [];
  const warnings: string[] = [];

  const exactPhraseCount = countExactPhrases(evidence);
  if (exactPhraseCount > 0) {
    score += Math.min(28, exactPhraseCount * 9);
    evidenceSources.push("exact_phrase");
    whyThisFeltSpecific.push(
      `${exactPhraseCount} exact phrase snippet${exactPhraseCount === 1 ? "" : "s"} pulled from your words.`,
    );
  } else {
    warnings.push("No exact phrase snippets — insight may feel generic.");
  }

  if (recurrenceCount >= 2) {
    score += Math.min(22, recurrenceCount * 4);
    evidenceSources.push("recurrence");
    whyThisFeltSpecific.push(
      `Language or pattern recurred ${recurrenceCount} time${recurrenceCount === 1 ? "" : "s"}.`,
    );
  }

  const uniqueEntries = [...new Set(entryIds)];
  if (uniqueEntries.length >= 2) {
    score += Math.min(22, uniqueEntries.length * 5);
    evidenceSources.push("related_entries");
    whyThisFeltSpecific.push(
      `Grounded across ${uniqueEntries.length} related saved moment${uniqueEntries.length === 1 ? "" : "s"}.`,
    );
  } else if (uniqueEntries.length === 1) {
    warnings.push("Single-moment signal — more saved moments would strengthen this.");
  }

  if (entriesById && uniqueEntries.length >= 2) {
    const weekKeys = new Set<string>();
    for (const id of uniqueEntries) {
      const entry = entriesById.get(id);
      if (entry) weekKeys.add(weekKeyForEntry(entry));
    }
    if (weekKeys.size >= 2) {
      score += 14;
      evidenceSources.push("cross_week");
      whyThisFeltSpecific.push(
        `Evidence spans ${weekKeys.size} calendar weeks — not just one sitting.`,
      );
    }
  }

  if (type === "contradiction") {
    score += 14;
    evidenceSources.push("contradiction");
    whyThisFeltSpecific.push(
      "Contradiction or reversal evidence links multiple statements you made.",
    );
  }

  const hasEntitySignal =
    type === "entity_trigger" ||
    /\bmentioned\b/i.test(text) ||
    /\b\d+ times\b/i.test(text);
  if (hasEntitySignal) {
    score += 10;
    evidenceSources.push("entity_grounding");
    whyThisFeltSpecific.push(
      "Tied to a named person, topic, or recurring entity from your archive.",
    );
  }

  const datedEvidence = evidence.filter((e) => e.dateLabel?.trim()).length;
  if (datedEvidence > 0 || DAY_TIME_RE.test(text)) {
    score += 10;
    evidenceSources.push("date_time");
    whyThisFeltSpecific.push(
      datedEvidence > 0
        ? `${datedEvidence} evidence item${datedEvidence === 1 ? "" : "s"} anchored to dated saved moments.`
        : "Anchored to a day-of-week or time-window pattern in your words.",
    );
  }

  for (const pattern of GENERIC_PHRASES) {
    if (pattern.test(text)) {
      warnings.push("Contains generic saved-moment phrasing — may feel non-specific.");
      score = Math.max(0, score - 12);
      break;
    }
  }

  if (!/"[^"]{3,}"/.test(text) && exactPhraseCount === 0 && !/\d+\/\d+|\d+ (times|entries|uses)/.test(text)) {
    warnings.push("No quoted language or numeric grounding in the insight text.");
  }

  const specificityScore = Math.min(100, Math.round(score));
  const evidenceCount = Math.max(evidence.length, uniqueEntries.length, exactPhraseCount);

  const isWeakOrGeneric =
    specificityScore < 52 ||
    (exactPhraseCount === 0 && uniqueEntries.length < 2 && !/\d+\/\d+|\d+ → \d+/.test(text)) ||
    warnings.length >= 2;

  if (isWeakOrGeneric && !warnings.some((w) => w.includes("generic"))) {
    warnings.push("Overall specificity is low — consider waiting for more entries.");
  }

  if (whyThisFeltSpecific.length === 0) {
    whyThisFeltSpecific.push(
      "Limited grounding signals — this insight needs more transcript evidence.",
    );
  }

  return {
    specificityScore,
    evidenceCount,
    whyThisFeltSpecific: whyThisFeltSpecific.slice(0, 5),
    evidenceSources: [...new Set(evidenceSources)],
    isWeakOrGeneric,
    warnings: [...new Set(warnings)].slice(0, 4),
  };
}

export function evidenceSourceLabel(source: EvidenceSourceKey): string {
  const labels: Record<EvidenceSourceKey, string> = {
    exact_phrase: "Exact phrase",
    recurrence: "Recurrence",
    related_entries: "Related entries",
    cross_week: "Cross-week",
    contradiction: "Contradiction",
    entity_grounding: "Entity grounding",
    date_time: "Date / time",
  };
  return labels[source];
}

export function specificityLabel(score: number): string {
  if (score >= 75) return "Highly specific";
  if (score >= 55) return "Moderately specific";
  if (score >= 35) return "Partially specific";
  return "Weak / generic";
}
