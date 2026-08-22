import type { TheoryNotification } from "@/types/theory-notification";
import type {
  NotificationLifecycleEvent,
  NotificationLifecycleEventName,
  NotificationLifecycleRecord,
} from "@/types/notification-effectiveness";

export const NOTIFICATION_LIFECYCLE_EVENTS_KEY =
  "voicememory_theory_notification_lifecycle_events";
export const NOTIFICATION_LIFECYCLE_RECORDS_KEY =
  "voicememory_theory_notification_lifecycle";

const MAX_EVENTS = 2000;
const EXPIRE_AFTER_DAYS = 14;

export const NOTIFICATION_LIFECYCLE_EVENTS = {
  created: "notification_created",
  seen: "notification_seen",
  opened: "notification_opened",
  dismissed: "notification_dismissed",
  expired: "notification_expired",
} as const satisfies Record<string, NotificationLifecycleEventName>;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

export function hoursBetween(startIso: string, endIso: string): number {
  const ms = new Date(endIso).getTime() - new Date(startIso).getTime();
  return Math.max(0, ms / (1000 * 60 * 60));
}

function ageHoursAt(createdAt: string, at: string): number {
  return Math.round(hoursBetween(createdAt, at) * 10) / 10;
}

function readRecordsRaw(): NotificationLifecycleRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(NOTIFICATION_LIFECYCLE_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (row): row is NotificationLifecycleRecord =>
        Boolean(row) &&
        typeof row === "object" &&
        typeof (row as NotificationLifecycleRecord).notificationId === "string",
    );
  } catch {
    return [];
  }
}

function writeRecords(records: NotificationLifecycleRecord[]): void {
  getStorage()?.setItem(NOTIFICATION_LIFECYCLE_RECORDS_KEY, JSON.stringify(records));
}

export function readNotificationLifecycleRecords(): NotificationLifecycleRecord[] {
  return readRecordsRaw().sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function upsertRecord(
  partial: NotificationLifecycleRecord,
): NotificationLifecycleRecord {
  const records = readRecordsRaw();
  const index = records.findIndex((r) => r.notificationId === partial.notificationId);
  const existing = index >= 0 ? records[index] : null;
  const merged: NotificationLifecycleRecord = {
    notificationId: partial.notificationId,
    theoryId: partial.theoryId,
    type: partial.type,
    title: partial.title,
    body: partial.body,
    createdAt: partial.createdAt,
    seenAt: partial.seenAt ?? existing?.seenAt,
    openedAt: partial.openedAt ?? existing?.openedAt,
    dismissedAt: partial.dismissedAt ?? existing?.dismissedAt,
    expiredAt: partial.expiredAt ?? existing?.expiredAt,
  };
  if (index >= 0) {
    records[index] = merged;
  } else {
    records.push(merged);
  }
  writeRecords(records);
  return merged;
}

export function appendLifecycleEvent(event: NotificationLifecycleEvent): void {
  const store = getStorage();
  if (!store) return;
  try {
    const raw = store.getItem(NOTIFICATION_LIFECYCLE_EVENTS_KEY);
    const existing: NotificationLifecycleEvent[] = raw ? JSON.parse(raw) : [];
    const next = [...(Array.isArray(existing) ? existing : []), event].slice(-MAX_EVENTS);
    store.setItem(NOTIFICATION_LIFECYCLE_EVENTS_KEY, JSON.stringify(next));
  } catch {
    // Local-only — never block UX.
  }
}

export function readNotificationLifecycleEvents(): NotificationLifecycleEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(NOTIFICATION_LIFECYCLE_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as NotificationLifecycleEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function emitLifecycle(
  name: NotificationLifecycleEventName,
  notification: Pick<
    TheoryNotification,
    "id" | "theoryId" | "type" | "title" | "body" | "createdAt"
  >,
  at: string = new Date().toISOString(),
): void {
  appendLifecycleEvent({
    name,
    at,
    notificationId: notification.id,
    theoryId: notification.theoryId,
    type: notification.type,
    ageHours: ageHoursAt(notification.createdAt, at),
  });
}

export function recordNotificationCreated(notification: TheoryNotification): void {
  const now = new Date().toISOString();
  upsertRecord({
    notificationId: notification.id,
    theoryId: notification.theoryId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    createdAt: notification.createdAt,
  });
  emitLifecycle(NOTIFICATION_LIFECYCLE_EVENTS.created, notification, now);
}

export function recordNotificationsSeen(notifications: TheoryNotification[]): void {
  const now = new Date().toISOString();
  for (const notification of notifications) {
    const records = readRecordsRaw();
    const existing = records.find((r) => r.notificationId === notification.id);
    if (existing?.seenAt) continue;

    upsertRecord({
      notificationId: notification.id,
      theoryId: notification.theoryId,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      seenAt: now,
    });
    emitLifecycle(NOTIFICATION_LIFECYCLE_EVENTS.seen, notification, now);
  }
}

export function recordNotificationOpened(notification: TheoryNotification): void {
  const now = new Date().toISOString();
  upsertRecord({
    notificationId: notification.id,
    theoryId: notification.theoryId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    createdAt: notification.createdAt,
    openedAt: now,
  });
  emitLifecycle(NOTIFICATION_LIFECYCLE_EVENTS.opened, notification, now);
}

export function recordNotificationDismissed(notification: TheoryNotification): void {
  const now = new Date().toISOString();
  const records = readRecordsRaw();
  const existing = records.find((r) => r.notificationId === notification.id);
  if (existing?.openedAt || existing?.dismissedAt) return;

  upsertRecord({
    notificationId: notification.id,
    theoryId: notification.theoryId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    createdAt: notification.createdAt,
    dismissedAt: now,
  });
  emitLifecycle(NOTIFICATION_LIFECYCLE_EVENTS.dismissed, notification, now);
}

/** Mark notifications older than 14 days without open/dismiss as expired (once). */
export function syncExpiredNotifications(): number {
  const now = new Date().toISOString();
  const thresholdMs = EXPIRE_AFTER_DAYS * 24 * 60 * 60 * 1000;
  let expiredCount = 0;

  for (const record of readRecordsRaw()) {
    if (record.openedAt || record.dismissedAt || record.expiredAt) continue;
    const ageMs = Date.now() - new Date(record.createdAt).getTime();
    if (ageMs < thresholdMs) continue;

    upsertRecord({ ...record, expiredAt: now });
    emitLifecycle(
      NOTIFICATION_LIFECYCLE_EVENTS.expired,
      {
        id: record.notificationId,
        theoryId: record.theoryId,
        type: record.type,
        title: record.title,
        body: record.body,
        createdAt: record.createdAt,
      },
      now,
    );
    expiredCount += 1;
  }

  return expiredCount;
}

export function clearNotificationLifecycleForEval(): void {
  const store = getStorage();
  store?.removeItem(NOTIFICATION_LIFECYCLE_EVENTS_KEY);
  store?.removeItem(NOTIFICATION_LIFECYCLE_RECORDS_KEY);
}
