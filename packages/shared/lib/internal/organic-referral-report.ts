import {
  readArchiveAttachmentRecords,
} from "@/lib/archive/archive-attachment";
import {
  ARCHIVE_ATTACHMENT_STRONG_LEVELS,
} from "@/lib/archive/archive-attachment-copy";
import { PAYWALL_ATTRIBUTION_EVENT_NAMES } from "@/lib/metrics/paywall-attribution-events";
import {
  organicReferralReasonLabel,
  readOrganicReferralRecords,
  referralBlockerLabel,
} from "@/lib/retention/organic-referral";
import {
  ORGANIC_REFERRAL_STATUS_LABELS,
  ORGANIC_REFERRAL_STRONG_YES_OR_THOUGHT_PERCENT,
  ORGANIC_REFERRAL_STRONG_YES_PERCENT,
  ORGANIC_REFERRAL_WEAK_YES_PERCENT,
} from "@/lib/retention/organic-referral-copy";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { getPlanId } from "@/lib/subscription";
import {
  ORGANIC_REFERRAL_REASON_IDS,
  ORGANIC_REFERRAL_STATUS_IDS,
  REFERRAL_BLOCKER_IDS,
  type OrganicReferralReport,
  type OrganicReferralVerdict,
} from "@/types/organic-referral";

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

function hadSubscriptionSignal(anchorAt: string): boolean {
  if (getPlanId() === "pro") return true;
  return hadEventInWindow(anchorAt, SUBSCRIPTION_EVENTS, SUBSCRIPTION_WINDOW_MS);
}

function hadStrongAttachmentInWindow(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + OUTCOME_WINDOW_MS;
  return readArchiveAttachmentRecords().some((row) => {
    if (!ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(row.level)) return false;
    const at = eventAtMs(row.answeredAt);
    return at > start && at <= end;
  });
}

function verdictFromRates(
  yesPercent: number | null,
  yesOrThoughtPercent: number | null,
  total: number,
): OrganicReferralVerdict {
  if (total < 3) return "insufficient_data";
  if (yesPercent === null || yesOrThoughtPercent === null) return "insufficient_data";
  if (yesPercent >= ORGANIC_REFERRAL_STRONG_YES_PERCENT && yesOrThoughtPercent >= ORGANIC_REFERRAL_STRONG_YES_OR_THOUGHT_PERCENT) {
    return "strong";
  }
  if (yesPercent < ORGANIC_REFERRAL_WEAK_YES_PERCENT) return "weak";
  return "mixed";
}

function buildCriticalAnswer(
  verdict: OrganicReferralVerdict,
  yesPercent: number | null,
  yesOrThoughtPercent: number | null,
): string {
  if (verdict === "insufficient_data") {
    return "Not enough organic referral responses on this device to judge whether users naturally want to tell someone.";
  }
  if (verdict === "strong") {
    return `${yesPercent}% said Yes and ${yesOrThoughtPercent}% said Yes or Thought about it — users appear to organically recommend ArchiveMe.`;
  }
  if (verdict === "weak") {
    return `Only ${yesPercent}% said Yes — organic word-of-mouth may still be weak (weak signal <10% Yes).`;
  }
  return `${yesPercent}% Yes · ${yesOrThoughtPercent}% Yes or Thought about it — mixed organic referral signal (strong: ≥20% Yes, ≥40% Yes or Thought).`;
}

export function buildOrganicReferralReport(): OrganicReferralReport {
  const records = readOrganicReferralRecords();
  const total = records.length;

  const yesCount = records.filter((r) => r.status === "yes").length;
  const thoughtCount = records.filter((r) => r.status === "thought_about_it").length;
  const yesOrThoughtCount = yesCount + thoughtCount;

  const referralRate = rate(yesCount, total);
  const thoughtAboutItRate = rate(thoughtCount, total);
  const yesOrThoughtRate = rate(yesOrThoughtCount, total);

  const verdict = verdictFromRates(referralRate, yesOrThoughtRate, total);

  const withReason = records.filter((r) => r.referralReason);
  const reasonTotal = withReason.length;
  const referralReasons = ORGANIC_REFERRAL_REASON_IDS.map((id) => {
    const count = withReason.filter((r) => r.referralReason === id).length;
    return {
      id,
      label: organicReferralReasonLabel(id),
      count,
      sharePercent: rate(count, reasonTotal) ?? 0,
    };
  })
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);

  const withBlocker = records.filter((r) => r.referralBlocker);
  const blockerTotal = withBlocker.length;
  const referralBlockers = REFERRAL_BLOCKER_IDS.map((id) => {
    const count = withBlocker.filter((r) => r.referralBlocker === id).length;
    return {
      id,
      label: referralBlockerLabel(id),
      count,
      sharePercent: rate(count, blockerTotal) ?? 0,
    };
  })
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);

  const byStatusOutcomes = ORGANIC_REFERRAL_STATUS_IDS.map((status) => {
    const matching = records.filter((r) => r.status === status);
    const count = matching.length;
    let returns = 0;
    let subs = 0;
    let attachments = 0;
    for (const row of matching) {
      if (hadEventInWindow(row.answeredAt, RETURN_EVENTS, OUTCOME_WINDOW_MS)) returns += 1;
      if (hadSubscriptionSignal(row.answeredAt)) subs += 1;
      if (hadStrongAttachmentInWindow(row.answeredAt)) attachments += 1;
    }
    return {
      status,
      label: ORGANIC_REFERRAL_STATUS_LABELS[status],
      count,
      retentionRate: rate(returns, count),
      attachmentRate: rate(attachments, count),
      subscriptionRate: rate(subs, count),
    };
  }).filter((row) => row.count > 0);

  return {
    criticalQuestion: "Would users naturally tell someone?",
    criticalAnswer: buildCriticalAnswer(verdict, referralRate, yesOrThoughtRate),
    verdict,
    referralRate,
    thoughtAboutItRate,
    yesOrThoughtRate,
    totalResponses: total,
    referralReasons,
    referralBlockers,
    byStatusOutcomes,
    recentRecords: records.slice(0, 12),
  };
}
