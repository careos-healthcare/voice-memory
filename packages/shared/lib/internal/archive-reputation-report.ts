import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { ARCHIVE_ATTACHMENT_STRONG_LEVELS } from "@/lib/archive/archive-attachment-copy";
import { archiveReputationLevelRank } from "@/lib/archive/archive-reputation";
import { ARCHIVE_REPUTATION_LEVEL_LABEL } from "@/lib/archive/archive-reputation-copy";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { getPlanId } from "@/lib/subscription";
import { PAYWALL_ATTRIBUTION_EVENT_NAMES } from "@/lib/metrics/paywall-attribution-events";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import type { ArchiveReputationLevel } from "@/types/archive-reputation";

const LEVELS: ArchiveReputationLevel[] = [
  "low",
  "developing",
  "moderate",
  "high",
  "very_high",
];

const WINDOW_MS = 14 * 24 * 60 * 60 * 1000;

function eventAtMs(iso: string): number {
  return new Date(iso).getTime();
}

function rate(count: number, total: number): number | null {
  if (total === 0) return null;
  return Math.round((count / total) * 100);
}

function hadReturnAfter(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + WINDOW_MS;
  const names = new Set([
    LAUNCH_EVENTS.memoryPageOpened,
    RETENTION_EVENTS.entryRecorded,
    "discover_opened",
    "returned_to_check_archive_view",
    "archive_belief_viewed",
  ]);
  return readLocalEvents().some((event) => {
    if (!names.has(event.name)) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

function hadPaywallConversionAfter(anchorAt: string): boolean {
  if (getPlanId() === "pro") return true;
  const start = eventAtMs(anchorAt);
  const end = start + WINDOW_MS;
  return readLocalEvents().some((event) => {
    if (event.name !== PAYWALL_ATTRIBUTION_EVENT_NAMES.conversion) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}


function hadStrongAttachmentAfter(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + WINDOW_MS;
  return readArchiveAttachmentRecords().some((record) => {
    if (!ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(record.level)) return false;
    const at = eventAtMs(record.answeredAt);
    return at > start && at <= end;
  });
}

function hadBeliefRecallResponseAfter(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + WINDOW_MS;
  return readLocalEvents().some((event) => {
    if (event.name !== "belief_recall_level") return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

export interface ArchiveReputationOutcomeRow {
  level: ArchiveReputationLevel;
  label: string;
  sampleSize: number;
  returnRate: number | null;
  attachmentRate: number | null;
  conversionRate: number | null;
  recallRate: number | null;
}

export interface ArchiveReputationReport {
  generatedAt: string;
  currentLevel: ArchiveReputationLevel | null;
  currentSummary: string | null;
  criticalQuestions: string[];
  byLevel: ArchiveReputationOutcomeRow[];
  lines: string[];
}

export function buildArchiveReputationReport(): ArchiveReputationReport {
  const entries = getMemoryEligibleEntries();
  const current = buildArchiveReputationView(entries);
  const anchorAt = new Date().toISOString();

  const byLevel: ArchiveReputationOutcomeRow[] = LEVELS.map((level) => {
    const rank = archiveReputationLevelRank(level);
    const isAtOrBelow = current
      ? archiveReputationLevelRank(current.level) >= rank
      : level === "low";

    return {
      level,
      label: ARCHIVE_REPUTATION_LEVEL_LABEL[level],
      sampleSize: isAtOrBelow ? 1 : 0,
      returnRate: isAtOrBelow && hadReturnAfter(anchorAt) ? 100 : null,
      attachmentRate: isAtOrBelow && hadStrongAttachmentAfter(anchorAt) ? 100 : null,
      conversionRate: isAtOrBelow && hadPaywallConversionAfter(anchorAt) ? 100 : null,
      recallRate: isAtOrBelow && hadBeliefRecallResponseAfter(anchorAt) ? 100 : null,
    };
  });

  const lines = [
    `Current reputation: ${current ? ARCHIVE_REPUTATION_LEVEL_LABEL[current.level] : "—"}`,
    "Reputation vs retention: compare return events in the window after each level threshold.",
    "Reputation vs conversion: compare paywall conversion signals by level band.",
    "Reputation vs attachment: compare strong attachment records by level band.",
    "Reputation vs belief recall: compare belief_recall_anchor loops by level band.",
  ];

  return {
    generatedAt: anchorAt,
    currentLevel: current?.level ?? null,
    currentSummary: current?.summary ?? null,
    criticalQuestions: [
      "Which reputation levels create attachment?",
      "Which reputation levels create return behavior?",
      "Which reputation levels create paywall conversion?",
      "Which reputation levels create belief recall?",
    ],
    byLevel,
    lines,
  };
}
