import type { ArchiveEmptyStateSpec } from "@/lib/design/archive-empty-state-copy";

export type ArchiveEmptyStateAuditResult = {
  ok: boolean;
  violations: string[];
};

export type ArchiveEmptyStateAuditEntry = {
  id: string;
  sourceFile: string;
  spec: ArchiveEmptyStateSpec;
};

/** Canonical empty states — headline, one sentence, one CTA. */
export const ARCHIVE_EMPTY_STATE_REGISTRY: ArchiveEmptyStateAuditEntry[] = [
  {
    id: "archive_no_belief",
    sourceFile: "components/archive/EvidenceArchiveHome.tsx",
    spec: {
      constantRef: "ARCHIVE_EMPTY_NO_BELIEF",
      headline: "No archive belief yet",
      body: "Record another reflection.",
      ctaLabel: "Record",
    },
  },
  {
    id: "belief_timeline",
    sourceFile: "components/archive/BeliefChangeTimeline.tsx",
    spec: {
      headline: "No belief changes yet",
      body: "A few more reflections unlock the timeline.",
      ctaLabel: null,
      constantRef: "BELIEF_TIMELINE_EMPTY",
    },
  },
];

export function auditEmptyStateSpec(
  source: string,
  entry: ArchiveEmptyStateAuditEntry,
): ArchiveEmptyStateAuditResult {
  const violations: string[] = [];
  const { spec } = entry;

  const hasRef = spec.constantRef ? source.includes(spec.constantRef) : false;
  if (!hasRef && !source.includes(spec.headline)) {
    violations.push(`${entry.id}: missing headline "${spec.headline}"`);
  }
  if (spec.body && !hasRef && !source.includes(spec.body)) {
    violations.push(`${entry.id}: missing body "${spec.body}"`);
  }
  if (spec.ctaLabel && !hasRef && !source.includes(spec.ctaLabel)) {
    violations.push(`${entry.id}: missing CTA "${spec.ctaLabel}"`);
  }

  const bannedExplainers = [
    "Not enough reflections yet for a current belief",
    "feature",
    "A few more entries let your archive compare",
  ];
  for (const phrase of bannedExplainers) {
    if (source.includes(phrase)) {
      violations.push(`${entry.id}: verbose empty copy (${phrase.slice(0, 24)}…)`);
    }
  }

  return { ok: violations.length === 0, violations };
}

/** @alias ArchiveEmptyStateAudit — registry-driven empty state checks. */
export function auditAllArchiveEmptyStates(
  readFile: (rel: string) => string,
): ArchiveEmptyStateAuditResult {
  const violations: string[] = [];
  for (const entry of ARCHIVE_EMPTY_STATE_REGISTRY) {
    const src = readFile(entry.sourceFile);
    const result = auditEmptyStateSpec(src, entry);
    violations.push(...result.violations);
  }
  return { ok: violations.length === 0, violations };
}
