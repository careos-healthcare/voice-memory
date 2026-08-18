import "server-only";

export type CuriosityHookType = "anchorFollowUp" | "blocker" | "momentum" | "returnWatch";

export interface CuriosityHookEntryMetadata {
  entryId: string;
  createdAt: string;
  extractedAnchors: string[];
  emotionalTone?: string;
  hasBlockers?: boolean;
  entryCount?: number;
}

export interface CuriosityHook {
  id: string;
  entryId: string;
  createdAt: string;
  primaryAnchor: string;
  hookType: CuriosityHookType;
  sourceEntryId?: string;
}

export interface CuriosityJournalEntryTiming {
  createdAt: string;
}

export type CuriosityEvidenceEligibilityReason =
  | "solid_pattern"
  | "strong_pattern"
  | "unsurfaced_contradiction"
  | "insufficient_evidence"
  | "already_surfaced"
  | "weak_match";

export interface CuriosityEvidenceGateResult {
  eligible: boolean;
  reason: CuriosityEvidenceEligibilityReason;
  confidenceBand: "weak" | "emerging" | "solid" | "strong";
  citedEntryIds: string[];
  themeLabel: string | null;
  excerpt: string | null;
  contradictionEntryIds: string[] | null;
  surfaceKey: string | null;
}

export interface CuriosityNotificationMessage {
  title: string;
  body: string;
  citedEntryIds: string[];
  hookId: string;
}

export interface QueuedCuriosityNotification {
  id: string;
  userId: string;
  deviceId: string;
  hookId: string;
  queryText: string;
  title: string;
  body: string;
  citedEntryIds: string[];
  fireAt: string;
}
