import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import { PAYWALL_ATTRIBUTION_EVENT_NAMES } from "@/lib/metrics/paywall-attribution-events";
import {
  attachmentReasonLabel,
  readArchiveAttachmentRecords,
} from "@/lib/archive/archive-attachment";
import {
  ARCHIVE_ATTACHMENT_LEVEL_LABELS,
  ARCHIVE_ATTACHMENT_STRONG_LEVELS,
  ARCHIVE_ATTACHMENT_STRONG_THRESHOLD_PERCENT,
  ARCHIVE_ATTACHMENT_WEAK_THRESHOLD_PERCENT,
} from "@/lib/archive/archive-attachment-copy";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { getPlanId } from "@/lib/subscription";
import {
  ARCHIVE_ATTACHMENT_LEVEL_IDS,
  ARCHIVE_ATTACHMENT_REASON_IDS,
  type ArchiveAttachmentLevelId,
  type ArchiveAttachmentReasonId,
  type ArchiveAttachmentReport,
  type ArchiveAttachmentVerdict,
} from "@/types/archive-attachment";

const OUTCOME_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const SUBSCRIPTION_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

const RETURN_EVENTS = new Set<string>([
  LAUNCH_EVENTS.memoryPageOpened,
  RETENTION_EVENTS.entryRecorded,
  "discover_opened",
  "returned_to_check_archive_view",
]);

const SUBSCRIPTION_EVENTS = new Set<string>([
  PAYWALL_ATTRIBUTION_EVENT_NAMES.conversion,
  LAUNCH_EVENTS.upgradeClicked,
]);

function eventAtMs(iso: string): number {
  return new Date(iso).getTime();
}

function rate(count: number, total: number): number | null {
  if (total === 0) return null;
  return Math.round((count / total) * 100);
}

function hadEventInWindow(anchorAt: string, names: Set<string>, windowMs: number): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + windowMs;
  return readLocalEvents().some((event) => {
    if (!names.has(event.name)) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

function hadBreakthroughInWindow(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + OUTCOME_WINDOW_MS;
  return readAllBreakthroughEvents().some((event) => {
    const at = eventAtMs(event.createdAt);
    return at > start && at <= end;
  });
}

function hadSubscriptionSignal(anchorAt: string): boolean {
  if (getPlanId() === "pro") return true;
  return hadEventInWindow(anchorAt, SUBSCRIPTION_EVENTS, SUBSCRIPTION_WINDOW_MS);
}

function verdictFromStrongPercent(strongPercent: number | null, total: number): ArchiveAttachmentVerdict {
  if (total < 3) return "insufficient_data";
  if (strongPercent === null) return "insufficient_data";
  if (strongPercent >= ARCHIVE_ATTACHMENT_STRONG_THRESHOLD_PERCENT) return "strong";
  if (strongPercent < ARCHIVE_ATTACHMENT_WEAK_THRESHOLD_PERCENT) return "weak";
  return "mixed";
}

function buildCriticalAnswer(
  verdict: ArchiveAttachmentVerdict,
  strongPercent: number | null,
  averageScore: number | null,
): string {
  if (verdict === "insufficient_data") {
    return "Not enough attachment responses on this device to judge whether users feel they own something valuable.";
  }
  const avg =
    averageScore !== null
      ? ` Average disappointment score: ${averageScore.toFixed(1)} / 4.`
      : "";
  if (verdict === "strong") {
    return `${strongPercent}% answered Very or Extremely — users appear to care about losing this archive.${avg}`;
  }
  if (verdict === "weak") {
    return `Only ${strongPercent}% answered Very or Extremely — attachment may still be weak.${avg}`;
  }
  return `${strongPercent}% answered Very or Extremely — mixed attachment signal.${avg}`;
}

export function buildArchiveAttachmentReport(): ArchiveAttachmentReport {
  const records = readArchiveAttachmentRecords();
  const total = records.length;

  const distribution = ARCHIVE_ATTACHMENT_LEVEL_IDS.map((level) => {
    const count = records.filter((r) => r.level === level).length;
    return {
      level,
      label: ARCHIVE_ATTACHMENT_LEVEL_LABELS[level],
      count,
      sharePercent: rate(count, total) ?? 0,
    };
  }).filter((row) => row.count > 0);

  const strongCount = records.filter((r) =>
    ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(r.level),
  ).length;
  const weakCount = records.filter((r) => r.level === "not_at_all" || r.level === "a_little").length;
  const strongAttachmentPercent = rate(strongCount, total);
  const weakAttachmentPercent = rate(weakCount, total);

  const averageAttachmentScore =
    total > 0
      ? Math.round((records.reduce((s, r) => s + r.score, 0) / total) * 10) / 10
      : null;

  const verdict = verdictFromStrongPercent(strongAttachmentPercent, total);

  const byLevelOutcomes = ARCHIVE_ATTACHMENT_LEVEL_IDS.map((level) => {
    const matching = records.filter((r) => r.level === level);
    const count = matching.length;
    let returns = 0;
    let subs = 0;
    let breakthroughs = 0;
    for (const row of matching) {
      if (hadEventInWindow(row.answeredAt, RETURN_EVENTS, OUTCOME_WINDOW_MS)) returns += 1;
      if (hadSubscriptionSignal(row.answeredAt)) subs += 1;
      if (hadBreakthroughInWindow(row.answeredAt)) breakthroughs += 1;
    }
    return {
      level,
      label: ARCHIVE_ATTACHMENT_LEVEL_LABELS[level],
      count,
      returnRate: rate(returns, count),
      subscriptionRate: rate(subs, count),
      breakthroughRate: rate(breakthroughs, count),
    };
  }).filter((row) => row.count > 0);

  const withReason = records.filter((r) => r.reason);
  const reasonTotal = withReason.length;
  const topAttachmentReasons = ARCHIVE_ATTACHMENT_REASON_IDS.map((reason) => {
    const count = withReason.filter((r) => r.reason === reason).length;
    return {
      reason,
      label: attachmentReasonLabel(reason),
      count,
      sharePercent: rate(count, reasonTotal) ?? 0,
    };
  })
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);

  const ageBuckets = [
    { label: "1–7 days", min: 1, max: 7 },
    { label: "8–30 days", min: 8, max: 30 },
    { label: "31–90 days", min: 31, max: 90 },
    { label: "90+ days", min: 91, max: 9999 },
  ];
  const ageParts: string[] = [];
  for (const bucket of ageBuckets) {
    const inBucket = records.filter(
      (r) => r.archiveAgeDays >= bucket.min && r.archiveAgeDays <= bucket.max,
    );
    if (inBucket.length === 0) continue;
    const avg =
      Math.round((inBucket.reduce((s, r) => s + r.score, 0) / inBucket.length) * 10) / 10;
    ageParts.push(`${bucket.label}: avg ${avg}/4 (n=${inBucket.length})`);
  }
  const archiveAgeSummary =
    ageParts.length > 0 ? ageParts.join(" · ") : "No archive-age breakdown yet.";

  return {
    criticalQuestion: "Do users feel they own something valuable?",
    criticalAnswer: buildCriticalAnswer(verdict, strongAttachmentPercent, averageAttachmentScore),
    verdict,
    strongAttachmentPercent,
    weakAttachmentPercent,
    averageAttachmentScore,
    totalResponses: total,
    distribution,
    byLevelOutcomes,
    topAttachmentReasons,
    archiveAgeSummary,
    recentRecords: records.slice(0, 12),
  };
}
