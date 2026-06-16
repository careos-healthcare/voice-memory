/**
 * Evidence policy — the explicit authority decision for each candidate,
 * made before any model/AI interpretation sees it.
 *
 * Order of authority, mirroring the mobile Memory Scope Controls and
 * Memory Authority Framing (the web side never overrides them):
 * 1. Unknown and generated sources are rejected outright.
 * 2. Memory scope off blocks all archive evidence.
 * 3. Treat-as-new / unapproved entries are suppressed.
 * 4. User confirmation is the only path to high authority — retrieval
 *    relevance alone can not produce it.
 * 5. Conflicting/superseded/stale evidence is marked as such and
 *    treated as background, not current.
 */

import {
  type AuthorityState,
  type EvidenceReasonId,
  type InfluenceLevel,
  influenceAdmitsEvidence,
} from "./evidence-authority";
import {
  type EvidenceCandidate,
  type EvidenceSourceType,
  isKnownSourceType,
} from "./evidence-source";

/** Mirrors the mobile memory scope ids — never overridden here. */
export type WebMemoryScope = "automatic" | "ask" | "thread_only" | "off";

const WEB_MEMORY_SCOPES: readonly WebMemoryScope[] = [
  "automatic",
  "ask",
  "thread_only",
  "off",
];

export function isWebMemoryScope(value: unknown): value is WebMemoryScope {
  return (
    typeof value === "string" &&
    (WEB_MEMORY_SCOPES as readonly string[]).includes(value)
  );
}

export type EvidenceAgeBucket =
  | "same_day"
  | "within_week"
  | "within_month"
  | "older"
  | "unknown";

export interface EvidenceDecision {
  sourceType: EvidenceSourceType | null;
  authorityState: AuthorityState;
  influenceLevel: InfluenceLevel;
  reasonId: EvidenceReasonId;
  ageBucket: EvidenceAgeBucket;
  /** Whether the item may enter the evidence packet at all. */
  admitted: boolean;
}

export function evidenceAgeBucket(
  createdAt: Date | string | undefined,
  now: Date,
): EvidenceAgeBucket {
  if (!createdAt) return "unknown";
  const created = typeof createdAt === "string" ? new Date(createdAt) : createdAt;
  if (Number.isNaN(created.getTime())) return "unknown";
  const days = Math.floor((now.getTime() - created.getTime()) / 86_400_000);
  if (days <= 0) return "same_day";
  if (days <= 7) return "within_week";
  if (days <= 30) return "within_month";
  return "older";
}

export function decideEvidenceAuthority(
  candidate: EvidenceCandidate,
  options: { memoryScope: WebMemoryScope; now: Date },
): EvidenceDecision {
  const ageBucket = evidenceAgeBucket(candidate.createdAt, options.now);

  const decide = (
    sourceType: EvidenceSourceType | null,
    authorityState: AuthorityState,
    influenceLevel: InfluenceLevel,
    reasonId: EvidenceReasonId,
  ): EvidenceDecision => ({
    sourceType,
    authorityState,
    influenceLevel,
    reasonId,
    ageBucket,
    admitted: sourceType !== null && influenceAdmitsEvidence(influenceLevel),
  });

  // Unknown source types are rejected — origin is part of evidence.
  if (!isKnownSourceType(candidate.sourceType)) {
    return decide(null, "blocked", "blocked", "unknown_source");
  }
  const sourceType = candidate.sourceType;

  // Generated model text is never evidence, no matter how it arrives.
  if (sourceType === "generated_interpretation") {
    return decide(sourceType, "blocked", "blocked", "generated_text");
  }

  if (sourceType === "current_entry") {
    // The present entry is what is being interpreted — it is not
    // memory, so memory scope does not block it.
    return decide(sourceType, "current", "compare", "source_current");
  }

  if (sourceType === "account_state" || sourceType === "product_state") {
    // Factual state only — informs interpretation, but it is not
    // emotional evidence and can not carry comparison claims.
    return decide(sourceType, "current", "background", "source_current");
  }

  if (sourceType === "web_result") {
    if (candidate.conflictsWithNewer) {
      return decide(sourceType, "conflicting", "background", "mixed_evidence");
    }
    if (candidate.supersededByNewer) {
      return decide(sourceType, "superseded", "background", "changed_later");
    }
    if (ageBucket === "same_day" || ageBucket === "within_week") {
      return decide(sourceType, "current", "compare", "source_current");
    }
    return decide(sourceType, "background", "background", "source_background");
  }

  // user_archive — the mobile memory controls always win.
  if (options.memoryScope === "off") {
    return decide(sourceType, "blocked", "blocked", "memory_off");
  }
  if (candidate.treatAsNew) {
    return decide(sourceType, "fresh", "suppress", "fresh_entry");
  }
  const confirmed = candidate.userConfirmed || candidate.connectionApproved;
  if (options.memoryScope === "ask" && !confirmed) {
    return decide(sourceType, "fresh", "suppress", "unapproved");
  }
  if (options.memoryScope === "thread_only" && !candidate.hasSharedThreadMarker) {
    return decide(sourceType, "fresh", "suppress", "fresh_entry");
  }
  // The only path to high authority — relevance scores are never read.
  if (confirmed) {
    return decide(sourceType, "confirmed", "high_authority", "user_confirmed");
  }
  if (candidate.conflictsWithNewer) {
    return decide(sourceType, "conflicting", "background", "mixed_evidence");
  }
  if (candidate.supersededByNewer) {
    return decide(sourceType, "superseded", "background", "changed_later");
  }
  if (ageBucket === "older") {
    return decide(sourceType, "stale", "background", "older_unreinforced");
  }
  if (ageBucket === "same_day" || ageBucket === "within_week") {
    return decide(sourceType, "current", "compare", "recent_supported");
  }
  return decide(sourceType, "background", "background", "source_background");
}
