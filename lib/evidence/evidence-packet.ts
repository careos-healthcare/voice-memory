/**
 * Evidence packet — the small structured object that reaches
 * interpretation instead of a loose context dump. Every item carries
 * its origin, authority, influence, and reason; nothing carries raw
 * user content.
 */

import type { AuthorityState, EvidenceReasonId, InfluenceLevel } from "./evidence-authority";
import type { EvidenceAgeBucket } from "./evidence-policy";
import type { EvidenceSourceType } from "./evidence-source";

/** Top relevant evidence only — interpretation never needs more. */
export const DEFAULT_MAX_EVIDENCE_ITEMS = 5;

export interface EvidencePacketWebMeta {
  domain: string | null;
  title: string | null;
  url: string | null;
}

export interface EvidencePacketItem {
  source_type: EvidenceSourceType;
  authority_state: AuthorityState;
  influence_level: InfluenceLevel;
  reason_id: EvidenceReasonId;
  age_bucket: EvidenceAgeBucket;
  /** Safe stable id only, or null. Never user text. */
  source_ref: string | null;
  /** Only present when an already-safe producer supplied it; redacted. */
  content_summary: string | null;
  /** Structural guarantee: every item went through redaction policy. */
  private_content_redacted: true;
  /** Public source metadata — web results only. */
  web?: EvidencePacketWebMeta;
}

export interface EvidencePacket {
  items: EvidencePacketItem[];
  /** Candidates rejected or suppressed before the packet. */
  blocked_count: number;
  /** The memory scope the packet was built under. */
  memory_scope: string;
  max_items: number;
}

export function emptyEvidencePacket(
  memoryScope: string,
  blockedCount = 0,
  maxItems = DEFAULT_MAX_EVIDENCE_ITEMS,
): EvidencePacket {
  return {
    items: [],
    blocked_count: blockedCount,
    memory_scope: memoryScope,
    max_items: maxItems,
  };
}
