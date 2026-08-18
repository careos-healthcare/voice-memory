import type { TheoryNotificationType } from "@/types/theory-notification";

export const NOTIFICATION_LIFECYCLE_EVENT_NAMES = [
  "notification_created",
  "notification_seen",
  "notification_opened",
  "notification_dismissed",
  "notification_expired",
] as const;

export type NotificationLifecycleEventName =
  (typeof NOTIFICATION_LIFECYCLE_EVENT_NAMES)[number];

export interface NotificationLifecycleEvent {
  name: NotificationLifecycleEventName;
  at: string;
  notificationId: string;
  theoryId: string;
  type: TheoryNotificationType;
  ageHours?: number;
}

export interface NotificationLifecycleRecord {
  notificationId: string;
  theoryId: string;
  type: TheoryNotificationType;
  title: string;
  body: string;
  createdAt: string;
  seenAt?: string;
  openedAt?: string;
  dismissedAt?: string;
  expiredAt?: string;
}

export interface NotificationTypeMetrics {
  type: TheoryNotificationType;
  total: number;
  opened: number;
  dismissed: number;
  unread: number;
  openRate: number | null;
  dismissRate: number | null;
  unreadRate: number | null;
  averageTimeToOpenHours: number | null;
  returnWithin24h: number;
  returnRate: number | null;
  insightWithin24h: number;
  insightRate: number | null;
  discoverVisitsWithin24h: number;
}

export interface NotificationCopyPerformance {
  title: string;
  body: string;
  type: TheoryNotificationType;
  total: number;
  opened: number;
  openRate: number | null;
  returnRate: number | null;
}

export interface DeadNotificationFlag {
  notificationId: string;
  theoryId: string;
  type: TheoryNotificationType;
  title: string;
  reason: "unopened_14d" | "low_open_rate_type" | "no_discover_visits_type";
  detail: string;
}

export interface NotificationEffectivenessReport {
  generatedAt: string;
  totalNotifications: number;
  openRate: number | null;
  dismissRate: number | null;
  unreadRate: number | null;
  averageTimeToOpenHours: number | null;
  opensByType: Record<TheoryNotificationType, number>;
  strongestNotificationType: TheoryNotificationType | null;
  weakestNotificationType: TheoryNotificationType | null;
  notificationReturnRate: number | null;
  notificationToInsightRate: number | null;
  byType: NotificationTypeMetrics[];
  deadNotifications: DeadNotificationFlag[];
  bestCopy: NotificationCopyPerformance[];
  winningReportTitle: string;
  winningByOpenRate: NotificationTypeMetrics[];
  winningByReturnRate: NotificationTypeMetrics[];
  winningByInsightRate: NotificationTypeMetrics[];
  lifecycleEventCounts: Record<NotificationLifecycleEventName, number>;
}
