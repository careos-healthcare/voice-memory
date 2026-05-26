import {
  buildQuietNotificationPayload,
  getQuietTrigger,
  QUIET_NOTIFICATION_TRIGGERS,
  type QuietNotificationTrigger,
} from "@/lib/notifications/triggers";
import type { QuietNotificationKind } from "@/lib/notifications/notification-copy";
import { supportsPush } from "@/lib/mobile/platform";

const QUEUE_KEY = "voicememory_notification_placeholder_queue";

export interface ScheduledQuietNotification {
  id: string;
  kind: QuietNotificationKind;
  scheduledAt: string;
  earliestSendAt: string;
  status: "queued" | "suppressed" | "sent_placeholder";
  reason?: string;
}

export interface NotificationSchedulerStatus {
  mode: "placeholder";
  pushCapable: boolean;
  registeredTriggers: number;
  queuedCount: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readQueue(): ScheduledQuietNotification[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(QUEUE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as ScheduledQuietNotification[];
  } catch {
    return [];
  }
}

function writeQueue(rows: ScheduledQuietNotification[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(QUEUE_KEY, JSON.stringify(rows.slice(-50)));
}

/** Queue a future quiet notification — does not display anything yet. */
export function queueQuietNotification(
  kind: QuietNotificationKind,
  options?: { delayHours?: number; reason?: string },
): ScheduledQuietNotification | null {
  const trigger = getQuietTrigger(kind);
  if (!trigger?.enabled) return null;

  const delayHours = Math.max(trigger.minIntervalHours, options?.delayHours ?? trigger.minIntervalHours);
  const now = Date.now();
  const row: ScheduledQuietNotification = {
    id: crypto.randomUUID(),
    kind,
    scheduledAt: new Date(now).toISOString(),
    earliestSendAt: new Date(now + delayHours * 60 * 60 * 1000).toISOString(),
    status: "queued",
    reason: options?.reason,
  };

  const queue = readQueue();
  queue.push(row);
  writeQueue(queue);
  return row;
}

/** Placeholder flush — logs only in development; never spams the user. */
export function flushPlaceholderNotificationQueue(): ScheduledQuietNotification[] {
  const queue = readQueue();
  const now = Date.now();
  const due = queue.filter((row) => new Date(row.earliestSendAt).getTime() <= now);

  if (due.length === 0) return [];

  const updated = queue.map((row) =>
    due.some((d) => d.id === row.id)
      ? { ...row, status: "sent_placeholder" as const }
      : row,
  );
  writeQueue(updated);

  if (process.env.NODE_ENV !== "production") {
    for (const row of due) {
      const payload = buildQuietNotificationPayload(row.kind);
      console.info("[notifications:placeholder]", payload.title, payload.body);
    }
  }

  return due;
}

export function getNotificationSchedulerStatus(): NotificationSchedulerStatus {
  return {
    mode: "placeholder",
    pushCapable: supportsPush(),
    registeredTriggers: QUIET_NOTIFICATION_TRIGGERS.length,
    queuedCount: readQueue().filter((row) => row.status === "queued").length,
  };
}

export function listQuietTriggers(): QuietNotificationTrigger[] {
  return QUIET_NOTIFICATION_TRIGGERS;
}

export function clearPlaceholderNotificationQueue(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(QUEUE_KEY);
}
