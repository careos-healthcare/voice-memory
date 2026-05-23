export interface RepeatedPhraseMatch {
  phrase: string;
  count: number;
  entryCount: number;
  example: string;
  category: "linguistic_habit" | "metaphor" | "framing";
}

export interface ContradictionMatch {
  id: string;
  label: string;
  detail: string;
  priorEntryId?: string;
  kind:
    | "conflicting_statement"
    | "failed_intention"
    | "emotional_reversal"
    | "goal_behavior_tension"
    | "want_vs_keep_doing";
}

export interface AvoidanceSignal {
  id: string;
  label: string;
  detail: string;
  kind: "vague_reference" | "unnamed_stressor" | "indirect_reference" | "emotional_hedging";
}

export interface EmotionalEvolutionSignal {
  id: string;
  label: string;
  detail: string;
  kind: "intensity_drift" | "day_of_week" | "recurring_trigger" | "emotional_cycle" | "recurring_context";
}

export interface PatternDebugScore {
  exactPhraseReferences: number;
  recurrenceCount: number;
  crossEntryGrounding: number;
  contradictionEvidence: number;
  total: number;
  specificityReasons: string[];
}

export interface EntryPatternInsights {
  entryId: string;
  recurringPatterns: string[];
  observations: string[];
  contradictions: ContradictionMatch[];
  repeatedPhrases: RepeatedPhraseMatch[];
  avoidanceSignals: AvoidanceSignal[];
  emotionalEvolution: EmotionalEvolutionSignal[];
  debug: PatternDebugScore;
}
