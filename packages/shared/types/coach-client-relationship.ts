/**
 * Professional / coach persona contracts.
 *
 * Distinct from caregiver monitoring — session-planning read surfaces only.
 * No threshold alerts, no passive monitoring semantics.
 */

import type { ArchiveInsightKind } from "@/types/insights";

export type CoachClientRelationshipStatus =
  | "invited"
  | "consent_pending"
  | "active"
  | "revoked"
  | "expired";

export const COACH_CLIENT_RELATIONSHIP_STATUSES = [
  "invited",
  "consent_pending",
  "active",
  "revoked",
  "expired",
] as const satisfies readonly CoachClientRelationshipStatus[];

/** Insight kinds coaches may use for session planning when consented. */
export const COACH_SESSION_PLANNING_INSIGHT_KINDS = [
  "belief",
  "beliefChange",
  "blindSpot",
  "contradiction",
  "theme",
  "breakthrough",
] as const satisfies readonly ArchiveInsightKind[];

export type CoachSessionPlanningInsightKind =
  (typeof COACH_SESSION_PLANNING_INSIGHT_KINDS)[number];

/** Client-controlled scopes exposed to a linked coach after verified consent. */
export interface CoachSharingPermissions {
  /** Saved fact_ledger rows (labels + cite metadata — not raw audio). */
  factLedger: boolean;
  /** Confidence-banded insight summaries from the evidence method. */
  confidenceBandedInsights: boolean;
  /** Which [ArchiveInsightKind] values may appear on the coach dashboard. */
  insightKinds: readonly ArchiveInsightKind[];
}

export const DEFAULT_COACH_SHARING_PERMISSIONS: CoachSharingPermissions = {
  factLedger: false,
  confidenceBandedInsights: true,
  insightKinds: ["belief", "blindSpot", "contradiction"],
};

/**
 * Long-lived link between a coach identity and a client archive owner.
 * Consent tokens authorize read access; this record tracks lifecycle state.
 */
export interface CoachClientRelationship {
  relationshipId: string;
  coachId: string;
  clientAccountId: string;
  /** Optional display label for coach dashboard (never raw transcript). */
  clientDisplayName?: string;
  status: CoachClientRelationshipStatus;
  permissions: CoachSharingPermissions;
  /** ISO-8601 UTC */
  createdAt: string;
  /** ISO-8601 UTC */
  updatedAt: string;
  activeConsentTokenId?: string;
}

/**
 * Cryptographically signed client opt-in before coach dashboard unlocks.
 * Canonical payload is HMAC-SHA256 signed (see client-consent-verification).
 */
export interface CoachConsentToken {
  tokenId: string;
  relationshipId: string;
  clientAccountId: string;
  coachId: string;
  permissions: CoachSharingPermissions;
  /** ISO-8601 UTC */
  issuedAt: string;
  /** ISO-8601 UTC */
  expiresAt: string;
  policyVersion: number;
  /** SHA-256 hex of normalized client affirmation sentence. */
  clientAffirmationHash: string;
  /** HMAC-SHA256 hex over canonical payload. */
  signature: string;
}

/** Active coach read session derived from a verified consent token. */
export interface CoachSession {
  sessionId: string;
  mode: "professionalCoach";
  coachId: string;
  clientAccountId: string;
  relationshipId: string;
  permissions: CoachSharingPermissions;
  tokenId: string;
  /** ISO-8601 UTC */
  startedAt: string;
  /** ISO-8601 UTC */
  expiresAt: string;
  /** ISO-8601 UTC */
  validatedAt: string;
}

export type CoachAuditAction =
  | "relationship_created"
  | "consent_granted"
  | "consent_revoked"
  | "session_started"
  | "session_validated"
  | "session_expired"
  | "fact_ledger_read"
  | "insight_read"
  | "dashboard_viewed"
  | "access_denied";

export interface CoachAuditLogEntry {
  entryId: string;
  sessionId: string;
  action: CoachAuditAction;
  resourceType: string;
  resourceId?: string;
  /** ISO-8601 UTC */
  timestamp: string;
  metadata?: Record<string, string | number | boolean | null>;
}

export interface CoachTokenVerificationResult {
  valid: boolean;
  reason?: string;
  session?: CoachSession;
}
