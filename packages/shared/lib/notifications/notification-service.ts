/**
 * Notification service — explicit status. No fake push until a provider is wired.
 */

import {
  queueQuietNotification,
  type ScheduledQuietNotification,
} from "@/lib/notifications/scheduler";
import type { QuietNotificationKind } from "@/lib/notifications/notification-copy";

export type NotificationServiceStatus =
  | "disabled"
  | "unavailable"
  | "permission_required"
  | "placeholder_dev_only";

export interface NotificationServiceState {
  status: NotificationServiceStatus;
  canSchedule: boolean;
  reason: string;
}

export function getNotificationServiceState(): NotificationServiceState {
  if (typeof window === "undefined") {
    return {
      status: "unavailable",
      canSchedule: false,
      reason: "Notifications are only available in the browser.",
    };
  }

  if (!("Notification" in window)) {
    return {
      status: "unavailable",
      canSchedule: false,
      reason: "This browser does not support notifications.",
    };
  }

  if (process.env.NODE_ENV === "production") {
    return {
      status: "disabled",
      canSchedule: false,
      reason: "Push is not enabled yet. In-app reminders only.",
    };
  }

  return {
    status: "placeholder_dev_only",
    canSchedule: false,
    reason: "Development placeholder — queue logs only, no delivery.",
  };
}

export function scheduleQuietNotification(kind: QuietNotificationKind): ScheduledQuietNotification | null {
  const state = getNotificationServiceState();
  if (state.status === "placeholder_dev_only") {
    return queueQuietNotification(kind);
  }
  return null;
}
