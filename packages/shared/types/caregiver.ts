/**
 * Caregiver / monitoring persona contracts (v2).
 *
 * Shared between mobile, API, and audit pipelines. Caregiver access is
 * read-only, consent-gated, and fully audited — no write paths on shared
 * archives without returning to selfReflection mode.
 */

/** Product persona — avoids separate binary forks for alternate surfaces. */
export type AppMode = "selfReflection" | "caregiverMonitoring" | "professionalCoach";

export const APP_MODES = [
  "selfReflection",
  "caregiverMonitoring",
  "professionalCoach",
] as const satisfies readonly AppMode[];

export function isAppMode(value: unknown): value is AppMode {
  return typeof value === "string" && (APP_MODES as readonly string[]).includes(value);
}

/** Read-only scopes a caregiver may hold after explicit consent. */
export interface CaregiverPermissions {
  /** Evidence stream identifiers (e.g. `journal`, `proof_trail`, `timeline`). */
  evidenceStreamIds: readonly string[];
  /** May view generated review summaries (no raw transcript export). */
  reviewSummaries: boolean;
  /** May receive / view threshold-based insight alerts. */
  thresholdAlerts: boolean;
}

export const CAREGIVER_EVIDENCE_STREAMS = [
  "journal",
  "proof_trail",
  "timeline",
  "insight_alerts",
] as const satisfies readonly string[];

export type CaregiverEvidenceStreamId = (typeof CAREGIVER_EVIDENCE_STREAMS)[number];

/** Cryptographically signed consent artifact presented before monitoring unlocks. */
export interface MonitoringConsentToken {
  tokenId: string;
  /** Archive owner account id (subject being monitored). */
  subjectAccountId: string;
  /** Caregiver identity (email hash, invite id, or linked account id). */
  caregiverId: string;
  permissions: CaregiverPermissions;
  /** ISO-8601 UTC */
  issuedAt: string;
  /** ISO-8601 UTC */
  expiresAt: string;
  policyVersion: number;
  /** HMAC-SHA256 hex over canonical payload (see mobile verifier). */
  signature: string;
}

/** Active caregiver monitoring session derived from a verified consent token. */
export interface CaregiverSession {
  sessionId: string;
  mode: AppMode;
  caregiverId: string;
  subjectAccountId: string;
  permissions: CaregiverPermissions;
  tokenId: string;
  /** ISO-8601 UTC */
  startedAt: string;
  /** ISO-8601 UTC */
  expiresAt: string;
  /** ISO-8601 UTC — last successful cryptographic validation */
  validatedAt: string;
}

export type CaregiverAuditAction =
  | "session_started"
  | "session_validated"
  | "session_expired"
  | "mode_switched"
  | "consent_granted"
  | "consent_revoked"
  | "evidence_stream_read"
  | "review_summary_read"
  | "threshold_alert_read"
  | "dashboard_viewed"
  | "access_denied";

/** Append-only local audit record — structural metadata only, no transcript text. */
export interface AuditLogEntry {
  entryId: string;
  sessionId: string;
  action: CaregiverAuditAction;
  resourceType: string;
  resourceId?: string;
  /** ISO-8601 UTC */
  timestamp: string;
  metadata?: Record<string, string | number | boolean | null>;
}

/** Persisted app-mode configuration snapshot. */
export interface AppModeConfig {
  mode: AppMode;
  policyVersion: number;
  /** ISO-8601 UTC */
  updatedAt: string;
  activeSessionId?: string;
}

export interface CaregiverTokenVerificationResult {
  valid: boolean;
  reason?: string;
  session?: CaregiverSession;
}
