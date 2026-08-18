export type OpenLoopStatus = "open" | "softened" | "closed";

export type EmotionalShiftKind =
  | "heavier"
  | "softer"
  | "unresolved"
  | "uncertain"
  | "avoided_then_revisited";

/** Snapshot of a linked reflection — not raw analytics. */
export interface OpenLoopConnectedMoment {
  entryId: string;
  recordedAt: string;
  quoteFragment: string;
  emotionalLabel?: string;
}

/** User-owned unresolved thread — local-first emotional continuity. */
export interface OpenLoop {
  openLoopId: string;
  sourceEntryId: string;
  title: string;
  userNextStep: string;
  status: OpenLoopStatus;
  createdAt: string;
  updatedAt: string;
  lastMentionedAt: string;
  firstSeenAt: string;
  relatedEntryIds: string[];
  anchorPhrases: string[];
  concernLabel?: string;
  recurrenceCount: number;
  strongestAnchorPhrase: string;
  emotionalShiftSummary?: EmotionalShiftKind;
  connectedMoments: OpenLoopConnectedMoment[];
  mentionHistory: string[];
  closureNote?: string;
  closedAt?: string;
}

export interface OpenLoopWithEntryMeta extends OpenLoop {
  sourceEntryCreatedAt: string | null;
  sourceEntryDateLabel: string | null;
}

export interface OpenLoopPresentation extends OpenLoopWithEntryMeta {
  /** At most one evidence-backed continuity line. */
  resurfacingLine: string | null;
}
