/**
 * Evidence sources — where a piece of information came from, declared
 * before it can influence any AI interpretation.
 *
 * Evidence should be structured before it reaches interpretation:
 * finding information is separate from knowing its origin, freshness,
 * and authority. Generated model text is explicitly a source type so it
 * can be explicitly rejected — it is never evidence.
 */

export const EVIDENCE_SOURCE_TYPES = [
  "user_archive",
  "current_entry",
  "web_result",
  "account_state",
  "product_state",
  "generated_interpretation",
] as const;

export type EvidenceSourceType = (typeof EVIDENCE_SOURCE_TYPES)[number];

export function isKnownSourceType(value: string): value is EvidenceSourceType {
  return (EVIDENCE_SOURCE_TYPES as readonly string[]).includes(value);
}

/**
 * Ranking priority when the packet is capped — current entry outranks
 * archive history, which outranks web results; factual state comes
 * last. Generated interpretation has no priority because it is never
 * admitted at all.
 */
export const SOURCE_PRIORITY: Record<EvidenceSourceType, number> = {
  current_entry: 0,
  user_archive: 1,
  web_result: 2,
  account_state: 3,
  product_state: 4,
  generated_interpretation: 99,
};

/** Public web metadata for a web_result — publisher content, not user content. */
export interface WebSourceMeta {
  url?: string;
  domain?: string;
  title?: string;
}

/**
 * One raw candidate entering the pipeline. `sourceType` is a plain
 * string on purpose: unknown types must be rejected, not trusted.
 *
 * No raw user content belongs here. `contentSummary` is admitted into a
 * packet only when `summaryIsSafe` is set by an existing safe producer,
 * and only for non-user sources — user archive text has no path in.
 */
export interface EvidenceCandidate {
  sourceType: string;
  /** Stable id of the underlying record/result — sanitized before use. */
  sourceRef?: string;
  createdAt?: Date | string;
  /** Only set by producers whose copy is already safe/redacted. */
  contentSummary?: string;
  summaryIsSafe?: boolean;
  /** The user explicitly confirmed this connection (archive evidence). */
  userConfirmed?: boolean;
  /** Mobile parity flags — never overridden by the web pipeline. */
  treatAsNew?: boolean;
  connectionApproved?: boolean;
  hasSharedThreadMarker?: boolean;
  /** Relationship to newer evidence, decided by the caller's data. */
  conflictsWithNewer?: boolean;
  supersededByNewer?: boolean;
  /** Retrieval relevance — informative only; it can not raise authority. */
  relevanceScore?: number;
  web?: WebSourceMeta;
}
