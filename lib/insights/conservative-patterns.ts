import {
  buildPatternEngineReport,
  type PatternInsight,
  type PatternInsightType,
} from "@/lib/patterns/pattern-engine";
import { getEntries } from "@/lib/storage";

export type ConservativePatternKind =
  | "recurring_thought"
  | "contradiction"
  | "avoidance_signal"
  | "improvement_signal"
  | "emotional_trigger_candidate";

export interface ConservativePattern {
  id: string;
  kind: ConservativePatternKind;
  label: string;
  observation: string;
  detail: string;
  entryIds: string[];
}

const KIND_LABELS: Record<ConservativePatternKind, string> = {
  recurring_thought: "Words that returned",
  contradiction: "Did not line up",
  avoidance_signal: "Indirect wording",
  improvement_signal: "Shift in tone",
  emotional_trigger_candidate: "Name or topic returned",
};

const TYPE_TO_KIND: Partial<Record<PatternInsightType, ConservativePatternKind>> = {
  recurring_pattern: "recurring_thought",
  repeated_phrase: "recurring_thought",
  contradiction: "contradiction",
  avoidance_signal: "avoidance_signal",
  improvement_signal: "improvement_signal",
  entity_trigger: "emotional_trigger_candidate",
};

const PATTERN_DISCLAIMER =
  "Repeated words and concerns from your archive — each links to the reflection it came from. Not a diagnosis.";

function toConservativePattern(insight: PatternInsight): ConservativePattern | null {
  const kind = TYPE_TO_KIND[insight.type];
  if (!kind) return null;

  return {
    id: insight.id,
    kind,
    label: KIND_LABELS[kind],
    observation: insight.title,
    detail: insight.detail,
    entryIds: insight.entryIds,
  };
}

/** Pick at most one pattern per conservative category, ranked by engine score. */
export function buildConservativePatterns(): {
  patterns: ConservativePattern[];
  disclaimer: string;
  hasData: boolean;
} {
  const report = buildPatternEngineReport(getEntries(), {
    scope: "memory",
    limit: 20,
  });

  const byKind = new Map<ConservativePatternKind, ConservativePattern>();

  for (const insight of report.insights) {
    const mapped = toConservativePattern(insight);
    if (!mapped || byKind.has(mapped.kind)) continue;
    byKind.set(mapped.kind, mapped);
  }

  const order: ConservativePatternKind[] = [
    "recurring_thought",
    "contradiction",
    "avoidance_signal",
    "improvement_signal",
    "emotional_trigger_candidate",
  ];

  const patterns = order
    .map((kind) => byKind.get(kind))
    .filter((p): p is ConservativePattern => Boolean(p));

  return {
    patterns,
    disclaimer: PATTERN_DISCLAIMER,
    hasData: patterns.length > 0,
  };
}
