export type IntentionStatus = "open" | "returned" | "faded" | "changed";

export interface LongTermIntention {
  id: string;
  text: string;
  sourceEntryIds: string[];
  firstSeenAt: string;
  lastSeenAt: string;
  status: IntentionStatus;
  userLabel?: string;
}

export interface IntentionsReport {
  generatedAt: string;
  stillOpen: LongTermIntention[];
  changedOverTime: LongTermIntention[];
  fadedForNow: LongTermIntention[];
  hasData: boolean;
}
