/**
 * Evidence pipeline — turns raw candidates into a capped, structured,
 * redacted evidence packet before any model/AI interpretation runs.
 *
 * Memory should be evidence, not gravity: the packet says where each
 * item came from, whether it is current, whether newer evidence
 * changed it, and how much authority it deserves. Generated model text
 * is rejected so output can never be recycled as evidence.
 */

import {
  type EvidenceReasonId,
  explainEvidenceReason,
  INFLUENCE_RANK,
} from "./evidence-authority";
import {
  DEFAULT_MAX_EVIDENCE_ITEMS,
  type EvidencePacket,
  type EvidencePacketItem,
} from "./evidence-packet";
import {
  decideEvidenceAuthority,
  type EvidenceDecision,
  type WebMemoryScope,
} from "./evidence-policy";
import {
  redactText,
  sanitizeDomain,
  sanitizeSourceRef,
  sanitizeWebTitle,
} from "./evidence-redaction";
import { type EvidenceCandidate, SOURCE_PRIORITY } from "./evidence-source";

export interface BuildEvidencePacketOptions {
  /** Mirrors the mobile memory scope ids; defaults to automatic. */
  memoryScope?: WebMemoryScope;
  now?: Date;
  maxItems?: number;
}

export interface EvidencePipelineResult {
  packet: EvidencePacket;
  /** Per-candidate decisions, in input order — for callers and tests. */
  decisions: EvidenceDecision[];
}

/** The only property keys an evidence analytics payload may carry. */
export const EVIDENCE_ANALYTICS_PROPERTY_KEYS = [
  "source_type",
  "authority_state",
  "influence_level",
  "reason_id",
  "item_count",
] as const;

export type EvidenceAnalyticsProperties = Partial<
  Record<(typeof EVIDENCE_ANALYTICS_PROPERTY_KEYS)[number], string | number>
>;

export type EvidenceAnalyticsEvent =
  | "evidence_packet_built"
  | "evidence_packet_empty"
  | "evidence_item_blocked"
  | "evidence_source_used";

type EvidenceAnalyticsSink = (
  event: EvidenceAnalyticsEvent,
  properties: EvidenceAnalyticsProperties,
) => void;

/**
 * Default: no sink — nothing is logged anywhere unless a safe sink is
 * explicitly attached. Whatever the sink, only whitelisted keys with
 * stable-id string values or counts can pass through.
 */
let analyticsSink: EvidenceAnalyticsSink | null = null;

export function setEvidenceAnalyticsSink(sink: EvidenceAnalyticsSink | null): void {
  analyticsSink = sink;
}

const SAFE_VALUE_PATTERN = /^[a-z0-9_]{1,40}$/;

function track(event: EvidenceAnalyticsEvent, properties: EvidenceAnalyticsProperties): void {
  const sink = analyticsSink;
  if (!sink) return;
  const safe: EvidenceAnalyticsProperties = {};
  for (const key of EVIDENCE_ANALYTICS_PROPERTY_KEYS) {
    const value = properties[key];
    if (value === undefined) continue;
    if (typeof value === "number" && Number.isFinite(value)) {
      safe[key] = value;
    } else if (typeof value === "string" && SAFE_VALUE_PATTERN.test(value)) {
      safe[key] = value;
    }
  }
  sink(event, safe);
}

/**
 * Builds the structured evidence packet. Capped, ranked, and redacted:
 * - generated/unknown sources rejected,
 * - memory scope and treat-as-new respected for archive evidence,
 * - higher influence first, then source priority, then recency,
 * - no raw user content anywhere in the result.
 */
export function buildEvidencePacket(
  candidates: EvidenceCandidate[],
  options: BuildEvidencePacketOptions = {},
): EvidencePipelineResult {
  const memoryScope: WebMemoryScope = options.memoryScope ?? "automatic";
  const now = options.now ?? new Date();
  const maxItems = options.maxItems ?? DEFAULT_MAX_EVIDENCE_ITEMS;

  const decisions: EvidenceDecision[] = [];
  const admitted: { candidate: EvidenceCandidate; decision: EvidenceDecision }[] = [];
  let blockedCount = 0;

  for (const candidate of candidates) {
    const decision = decideEvidenceAuthority(candidate, { memoryScope, now });
    decisions.push(decision);
    if (decision.admitted) {
      admitted.push({ candidate, decision });
    } else {
      blockedCount += 1;
      track("evidence_item_blocked", {
        source_type: decision.sourceType ?? "unknown",
        authority_state: decision.authorityState,
        influence_level: decision.influenceLevel,
        reason_id: decision.reasonId,
      });
    }
  }

  admitted.sort((a, b) => {
    const byInfluence =
      INFLUENCE_RANK[b.decision.influenceLevel] - INFLUENCE_RANK[a.decision.influenceLevel];
    if (byInfluence !== 0) return byInfluence;
    const byPriority =
      SOURCE_PRIORITY[a.decision.sourceType!] - SOURCE_PRIORITY[b.decision.sourceType!];
    if (byPriority !== 0) return byPriority;
    return ageRank(a.decision.ageBucket) - ageRank(b.decision.ageBucket);
  });

  const items = admitted.slice(0, maxItems).map(({ candidate, decision }) => {
    const item = toPacketItem(candidate, decision);
    track("evidence_source_used", {
      source_type: item.source_type,
      authority_state: item.authority_state,
      influence_level: item.influence_level,
      reason_id: item.reason_id,
    });
    return item;
  });
  blockedCount += admitted.length - items.length;

  const packet: EvidencePacket = {
    items,
    blocked_count: blockedCount,
    memory_scope: memoryScope,
    max_items: maxItems,
  };

  track(items.length === 0 ? "evidence_packet_empty" : "evidence_packet_built", {
    item_count: items.length,
  });

  return { packet, decisions };
}

/**
 * "Why this source was used" — internal explanation from the stable
 * reason vocabulary only. No private content can appear here.
 */
export function explainEvidenceItem(item: EvidencePacketItem): {
  reasonId: EvidenceReasonId;
  explanation: string;
} {
  return { reasonId: item.reason_id, explanation: explainEvidenceReason(item.reason_id) };
}

function ageRank(bucket: EvidenceDecision["ageBucket"]): number {
  switch (bucket) {
    case "same_day":
      return 0;
    case "within_week":
      return 1;
    case "within_month":
      return 2;
    case "older":
      return 3;
    case "unknown":
      return 4;
  }
}

function toPacketItem(
  candidate: EvidenceCandidate,
  decision: EvidenceDecision,
): EvidencePacketItem {
  const sourceType = decision.sourceType!;

  // User text has no path into a packet: summaries are admitted only
  // for non-user sources, only when an already-safe producer marked
  // them safe, and they are still redacted on the way in.
  const summaryAllowed =
    candidate.summaryIsSafe === true &&
    sourceType !== "user_archive" &&
    sourceType !== "current_entry";
  const summary = summaryAllowed && candidate.contentSummary
    ? redactText(candidate.contentSummary) || null
    : null;

  const item: EvidencePacketItem = {
    source_type: sourceType,
    authority_state: decision.authorityState,
    influence_level: decision.influenceLevel,
    reason_id: decision.reasonId,
    age_bucket: decision.ageBucket,
    source_ref: sanitizeSourceRef(candidate.sourceRef),
    content_summary: summary,
    private_content_redacted: true,
  };

  if (sourceType === "web_result") {
    item.web = {
      domain: sanitizeDomain(candidate.web?.domain ?? candidate.web?.url),
      title: sanitizeWebTitle(candidate.web?.title),
      url: candidate.web?.url?.trim() || null,
    };
  }

  return item;
}
