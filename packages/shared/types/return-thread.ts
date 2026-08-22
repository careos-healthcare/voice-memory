export type ReturnThreadType =
  | "repeated_phrase"
  | "unresolved_problem"
  | "recurring_person"
  | "contradiction"
  | "changed_position"
  | "silence_then_return"
  | "emotional_reversal"
  | "recurring_uncertainty";

export interface ReturnThread {
  id: string;
  type: ReturnThreadType;
  anchorQuote: string;
  latestQuote: string;
  firstSeenAt: string;
  lastSeenAt: string;
  appearances: number;
  relatedEntryIds: string[];
  continuityLine: string;
  /** Person name, phrase stem, or topic — for high-confidence chips only. */
  contextLabel?: string;
  gapDays?: number;
}

export interface ReturnThreadGroups {
  wordsReturned: ReturnThread[];
  stillUnresolved: ReturnThread[];
  earlierNow: ReturnThread[];
  cameBack: ReturnThread[];
  repeatedSituations: ReturnThread[];
  peopleAgain: ReturnThread[];
}

export interface ReturnThreadsReport {
  threads: ReturnThread[];
  groups: ReturnThreadGroups;
  hasData: boolean;
}
