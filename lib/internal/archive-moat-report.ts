import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { ARCHIVE_MOAT_PERCEPTION_LABELS } from "@/lib/archive/archive-attachment-copy";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { PAYWALL_ATTRIBUTION_EVENT_NAMES } from "@/lib/metrics/paywall-attribution-events";
import {
  ARCHIVE_MOAT_PERCEPTION_IDS,
  type ArchiveMoatPerceptionId,
} from "@/types/archive-attachment";

const RETURN_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const CONVERSION_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

const RETURN_EVENTS = new Set<string>([
  LAUNCH_EVENTS.memoryPageOpened,
  RETENTION_EVENTS.entryRecorded,
  "discover_opened",
  "returned_to_check_archive_view",
]);

const CONVERSION_EVENTS = new Set<string>([
  PAYWALL_ATTRIBUTION_EVENT_NAMES.conversion,
  LAUNCH_EVENTS.upgradeClicked,
]);

export type ArchiveMoatPerceptionRow = {
  perception: ArchiveMoatPerceptionId;
  label: string;
  count: number;
  sharePercent: number;
};

export type ArchiveMoatReport = {
  criticalQuestion: string;
  criticalAnswer: string;
  totalMoatResponses: number;
  totalAttachmentResponses: number;
  replaceablePercent: number | null;
  irreplaceablePercent: number | null;
  perceptionDistribution: ArchiveMoatPerceptionRow[];
  attachmentByPerception: Array<{
    perception: ArchiveMoatPerceptionId;
    label: string;
    averageAttachmentScore: number | null;
    count: number;
  }>;
  returnRateByPerception: Array<{
    perception: ArchiveMoatPerceptionId;
    label: string;
    returnRate: number | null;
    count: number;
  }>;
  conversionRateByPerception: Array<{
    perception: ArchiveMoatPerceptionId;
    label: string;
    conversionRate: number | null;
    count: number;
  }>;
};

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
  return readLocalEvents().some((e) => {
    const at = eventAtMs(e.at);
    return at > start && at <= end && names.has(e.name);
  });
}

const REPLACEABLE: ArchiveMoatPerceptionId[] = ["definitely", "probably"];
const IRREPLACEABLE: ArchiveMoatPerceptionId[] = ["probably_not", "definitely_not"];

export function buildArchiveMoatReport(): ArchiveMoatReport {
  const records = readArchiveAttachmentRecords();
  const withMoat = records.filter((r) => r.archiveMoatPerception);
  const totalMoat = withMoat.length;
  const totalAttachment = records.length;

  const counts = new Map<ArchiveMoatPerceptionId, number>();
  for (const id of ARCHIVE_MOAT_PERCEPTION_IDS) counts.set(id, 0);
  for (const row of withMoat) {
    const id = row.archiveMoatPerception!;
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }

  const perceptionDistribution: ArchiveMoatPerceptionRow[] = ARCHIVE_MOAT_PERCEPTION_IDS.map(
    (perception) => {
      const count = counts.get(perception) ?? 0;
      return {
        perception,
        label: ARCHIVE_MOAT_PERCEPTION_LABELS[perception],
        count,
        sharePercent: rate(count, totalMoat) ?? 0,
      };
    },
  ).filter((row) => row.count > 0);

  const replaceable = withMoat.filter((r) =>
    REPLACEABLE.includes(r.archiveMoatPerception!),
  ).length;
  const irreplaceable = withMoat.filter((r) =>
    IRREPLACEABLE.includes(r.archiveMoatPerception!),
  ).length;

  const attachmentByPerception = ARCHIVE_MOAT_PERCEPTION_IDS.map((perception) => {
    const subset = withMoat.filter((r) => r.archiveMoatPerception === perception);
    const avg =
      subset.length > 0
        ? Math.round(
            (subset.reduce((sum, r) => sum + r.score, 0) / subset.length) * 10,
          ) / 10
        : null;
    return {
      perception,
      label: ARCHIVE_MOAT_PERCEPTION_LABELS[perception],
      averageAttachmentScore: avg,
      count: subset.length,
    };
  }).filter((row) => row.count > 0);

  const returnRateByPerception = ARCHIVE_MOAT_PERCEPTION_IDS.map((perception) => {
    const subset = withMoat.filter((r) => r.archiveMoatPerception === perception);
    const returned = subset.filter((r) =>
      hadEventInWindow(r.answeredAt, RETURN_EVENTS, RETURN_WINDOW_MS),
    ).length;
    return {
      perception,
      label: ARCHIVE_MOAT_PERCEPTION_LABELS[perception],
      returnRate: rate(returned, subset.length),
      count: subset.length,
    };
  }).filter((row) => row.count > 0);

  const conversionRateByPerception = ARCHIVE_MOAT_PERCEPTION_IDS.map((perception) => {
    const subset = withMoat.filter((r) => r.archiveMoatPerception === perception);
    const converted = subset.filter((r) =>
      hadEventInWindow(r.answeredAt, CONVERSION_EVENTS, CONVERSION_WINDOW_MS),
    ).length;
    return {
      perception,
      label: ARCHIVE_MOAT_PERCEPTION_LABELS[perception],
      conversionRate: rate(converted, subset.length),
      count: subset.length,
    };
  }).filter((row) => row.count > 0);

  let criticalAnswer =
    "No archive moat perception responses yet — run the attachment loss test in the archive.";
  if (totalMoat > 0) {
    const irreplaceablePct = rate(irreplaceable, totalMoat);
    const replaceablePct = rate(replaceable, totalMoat);
    criticalAnswer = `${irreplaceablePct ?? 0}% rate the archive as hard to recreate (${irreplaceable} of ${totalMoat}); ${replaceablePct ?? 0}% say another tool could probably do it.`;
  }

  return {
    criticalQuestion: "Do users believe this archive is replaceable?",
    criticalAnswer,
    totalMoatResponses: totalMoat,
    totalAttachmentResponses: totalAttachment,
    replaceablePercent: rate(replaceable, totalMoat),
    irreplaceablePercent: rate(irreplaceable, totalMoat),
    perceptionDistribution,
    attachmentByPerception,
    returnRateByPerception,
    conversionRateByPerception,
  };
}
