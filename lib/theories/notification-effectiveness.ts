import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import {
  hoursBetween,
  readNotificationLifecycleEvents,
  readNotificationLifecycleRecords,
  syncExpiredNotifications,
} from "@/lib/theories/theory-notification-lifecycle";
import { readAllTheoryEvents, THEORY_EVENTS } from "@/lib/theories/theory-events";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import type {
  DeadNotificationFlag,
  NotificationCopyPerformance,
  NotificationEffectivenessReport,
  NotificationLifecycleEventName,
  NotificationTypeMetrics,
} from "@/types/notification-effectiveness";
import type { TheoryNotificationType } from "@/types/theory-notification";

const ALL_TYPES: TheoryNotificationType[] = [
  "strengthened",
  "weakened",
  "contradiction",
  "new_evidence",
  "prediction_outcome",
  "resolved",
  "retired",
];

const RETURN_WINDOW_HOURS = 24;
const LOW_OPEN_RATE_THRESHOLD = 0.1;
const MIN_TYPE_SAMPLE_FOR_DEAD = 3;

function pct(numerator: number, denominator: number): number | null {
  if (denominator === 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function avg(values: number[]): number | null {
  if (values.length === 0) return null;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function withinHoursAfter(anchorIso: string, eventIso: string, hours: number): boolean {
  return hoursBetween(anchorIso, eventIso) <= hours;
}

function hadRecordWithin24h(openedAt: string): boolean {
  return readLocalEvents().some(
    (e) =>
      e.name === RETENTION_EVENTS.entryRecorded &&
      withinHoursAfter(openedAt, e.at, RETURN_WINDOW_HOURS),
  );
}

function hadDiscoverWithin24h(openedAt: string): boolean {
  return readAllTheoryEvents().some(
    (e) =>
      e.name === THEORY_EVENTS.discoverOpened &&
      withinHoursAfter(openedAt, e.at, RETURN_WINDOW_HOURS),
  );
}

function hadTheoriesWithin24h(openedAt: string, theoryId: string): boolean {
  return readAllTheoryEvents().some(
    (e) =>
      (e.name === THEORY_EVENTS.viewed ||
        e.name === THEORY_EVENTS.expanded ||
        e.name === THEORY_EVENTS.revisited) &&
      withinHoursAfter(openedAt, e.at, RETURN_WINDOW_HOURS) &&
      (!e.theoryId || e.theoryId === theoryId),
  );
}

function hadInsightReactionWithin24h(openedAt: string, theoryId: string): boolean {
  const theoryHit = readAllTheoryFeedback().some(
    (f) =>
      f.theoryId === theoryId &&
      f.reaction === "surprising" &&
      withinHoursAfter(openedAt, f.at, RETURN_WINDOW_HOURS),
  );
  if (theoryHit) return true;

  return readAllBlindSpotFeedback().some(
    (f) =>
      (f.reaction === "surprising" || f.reaction === "uncomfortably_accurate") &&
      withinHoursAfter(openedAt, f.at, RETURN_WINDOW_HOURS),
  );
}

function hadReturnWithin24h(
  openedAt: string,
  theoryId: string,
): { returned: boolean; discover: boolean; insight: boolean } {
  const record = hadRecordWithin24h(openedAt);
  const discover = hadDiscoverWithin24h(openedAt);
  const theories = hadTheoriesWithin24h(openedAt, theoryId);
  const insight = hadInsightReactionWithin24h(openedAt, theoryId);
  return {
    returned: record || discover || theories,
    discover,
    insight,
  };
}

function emptyOpensByType(): Record<TheoryNotificationType, number> {
  return Object.fromEntries(ALL_TYPES.map((t) => [t, 0])) as Record<
    TheoryNotificationType,
    number
  >;
}

function buildTypeMetrics(
  records: ReturnType<typeof readNotificationLifecycleRecords>,
): NotificationTypeMetrics[] {
  return ALL_TYPES.map((type) => {
    const rows = records.filter((r) => r.type === type);
    const total = rows.length;
    const opened = rows.filter((r) => r.openedAt).length;
    const dismissed = rows.filter((r) => r.dismissedAt && !r.openedAt).length;
    const unread = rows.filter(
      (r) => !r.openedAt && !r.dismissedAt && !r.expiredAt,
    ).length;

    const timeToOpen = rows
      .filter((r) => r.openedAt)
      .map((r) => hoursBetween(r.createdAt, r.openedAt!));

    let returnWithin24h = 0;
    let insightWithin24h = 0;
    let discoverVisitsWithin24h = 0;

    for (const row of rows) {
      if (!row.openedAt) continue;
      const attribution = hadReturnWithin24h(row.openedAt, row.theoryId);
      if (attribution.returned) returnWithin24h += 1;
      if (attribution.insight) insightWithin24h += 1;
      if (attribution.discover) discoverVisitsWithin24h += 1;
    }

    return {
      type,
      total,
      opened,
      dismissed,
      unread,
      openRate: pct(opened, total),
      dismissRate: pct(dismissed, total),
      unreadRate: pct(unread, total),
      averageTimeToOpenHours: avg(timeToOpen),
      returnWithin24h,
      returnRate: pct(returnWithin24h, opened),
      insightWithin24h,
      insightRate: pct(insightWithin24h, opened),
      discoverVisitsWithin24h,
    };
  });
}

function pickStrongestWeakest(
  metrics: NotificationTypeMetrics[],
): {
  strongest: TheoryNotificationType | null;
  weakest: TheoryNotificationType | null;
} {
  const withData = metrics.filter((m) => m.total > 0 && m.openRate !== null);
  if (withData.length === 0) {
    return { strongest: null, weakest: null };
  }
  const sorted = [...withData].sort((a, b) => (b.openRate ?? 0) - (a.openRate ?? 0));
  return {
    strongest: sorted[0]?.type ?? null,
    weakest: sorted[sorted.length - 1]?.type ?? null,
  };
}

function buildDeadFlags(
  records: ReturnType<typeof readNotificationLifecycleRecords>,
  byType: NotificationTypeMetrics[],
): DeadNotificationFlag[] {
  const flags: DeadNotificationFlag[] = [];
  const now = Date.now();
  const fourteenDaysMs = 14 * 24 * 60 * 60 * 1000;

  for (const record of records) {
    if (record.openedAt || record.dismissedAt) continue;
    const ageMs = now - new Date(record.createdAt).getTime();
    if (ageMs >= fourteenDaysMs) {
      flags.push({
        notificationId: record.notificationId,
        theoryId: record.theoryId,
        type: record.type,
        title: record.title,
        reason: "unopened_14d",
        detail: "Older than 14 days without open or dismiss",
      });
    }
  }

  for (const row of byType) {
    if (row.total >= MIN_TYPE_SAMPLE_FOR_DEAD && row.openRate !== null && row.openRate < 10) {
      flags.push({
        notificationId: `type:${row.type}`,
        theoryId: "",
        type: row.type,
        title: `Type: ${row.type}`,
        reason: "low_open_rate_type",
        detail: `Open rate ${row.openRate}% across ${row.total} notifications`,
      });
    }
    if (row.opened >= MIN_TYPE_SAMPLE_FOR_DEAD && row.discoverVisitsWithin24h === 0) {
      flags.push({
        notificationId: `type-discover:${row.type}`,
        theoryId: "",
        type: row.type,
        title: `Type: ${row.type}`,
        reason: "no_discover_visits_type",
        detail: `No discover visits within 24h after ${row.opened} opens`,
      });
    }
  }

  return flags;
}

function buildBestCopy(
  records: ReturnType<typeof readNotificationLifecycleRecords>,
): NotificationCopyPerformance[] {
  const groups = new Map<
    string,
    { title: string; body: string; type: TheoryNotificationType; total: number; opened: number; returns: number }
  >();

  for (const record of records) {
    const key = `${record.type}::${record.title}::${record.body}`;
    const group = groups.get(key) ?? {
      title: record.title,
      body: record.body,
      type: record.type,
      total: 0,
      opened: 0,
      returns: 0,
    };
    group.total += 1;
    if (record.openedAt) {
      group.opened += 1;
      if (hadReturnWithin24h(record.openedAt, record.theoryId).returned) {
        group.returns += 1;
      }
    }
    groups.set(key, group);
  }

  return [...groups.values()]
    .map((g) => ({
      title: g.title,
      body: g.body,
      type: g.type,
      total: g.total,
      opened: g.opened,
      openRate: pct(g.opened, g.total),
      returnRate: pct(g.returns, g.opened),
    }))
    .sort((a, b) => (b.openRate ?? 0) - (a.openRate ?? 0))
    .slice(0, 8);
}

function sortByRate(
  metrics: NotificationTypeMetrics[],
  field: "openRate" | "returnRate" | "insightRate",
): NotificationTypeMetrics[] {
  return [...metrics]
    .filter((m) => m.total > 0)
    .sort((a, b) => (b[field] ?? -1) - (a[field] ?? -1));
}

function lifecycleEventCounts(): Record<NotificationLifecycleEventName, number> {
  const counts = Object.fromEntries(
    (
      [
        "notification_created",
        "notification_seen",
        "notification_opened",
        "notification_dismissed",
        "notification_expired",
      ] as NotificationLifecycleEventName[]
    ).map((name) => [name, 0]),
  ) as Record<NotificationLifecycleEventName, number>;

  for (const event of readNotificationLifecycleEvents()) {
    if (event.name in counts) {
      counts[event.name] += 1;
    }
  }
  return counts;
}

export function buildNotificationEffectivenessReport(): NotificationEffectivenessReport {
  syncExpiredNotifications();
  const records = readNotificationLifecycleRecords();
  const totalNotifications = records.length;
  const openedCount = records.filter((r) => r.openedAt).length;
  const dismissedCount = records.filter((r) => r.dismissedAt && !r.openedAt).length;
  const unreadCount = records.filter(
    (r) => !r.openedAt && !r.dismissedAt && !r.expiredAt,
  ).length;

  const opensByType = emptyOpensByType();
  for (const record of records) {
    if (record.openedAt) {
      opensByType[record.type] += 1;
    }
  }

  const timeToOpenAll = records
    .filter((r) => r.openedAt)
    .map((r) => hoursBetween(r.createdAt, r.openedAt!));

  let returnCount = 0;
  let insightCount = 0;
  for (const record of records) {
    if (!record.openedAt) continue;
    const attribution = hadReturnWithin24h(record.openedAt, record.theoryId);
    if (attribution.returned) returnCount += 1;
    if (attribution.insight) insightCount += 1;
  }

  const byType = buildTypeMetrics(records);
  const { strongest, weakest } = pickStrongestWeakest(byType);

  return {
    generatedAt: new Date().toISOString(),
    totalNotifications,
    openRate: pct(openedCount, totalNotifications),
    dismissRate: pct(dismissedCount, totalNotifications),
    unreadRate: pct(unreadCount, totalNotifications),
    averageTimeToOpenHours: avg(timeToOpenAll),
    opensByType,
    strongestNotificationType: strongest,
    weakestNotificationType: weakest,
    notificationReturnRate: pct(returnCount, openedCount),
    notificationToInsightRate: pct(insightCount, openedCount),
    byType,
    deadNotifications: buildDeadFlags(records, byType),
    bestCopy: buildBestCopy(records),
    winningReportTitle: "What actually brings users back?",
    winningByOpenRate: sortByRate(byType, "openRate"),
    winningByReturnRate: sortByRate(byType, "returnRate"),
    winningByInsightRate: sortByRate(byType, "insightRate"),
    lifecycleEventCounts: lifecycleEventCounts(),
  };
}
