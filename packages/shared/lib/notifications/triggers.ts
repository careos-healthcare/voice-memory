import { NOTIFICATION_COPY, type QuietNotificationKind } from "@/lib/notifications/notification-copy";

export interface QuietNotificationTrigger {
  id: QuietNotificationKind;
  description: string;
  /** Minimum hours between sends for this trigger. */
  minIntervalHours: number;
  enabled: boolean;
}

/** Placeholder triggers — scheduler does not send until a provider is wired. */
export const QUIET_NOTIFICATION_TRIGGERS: QuietNotificationTrigger[] = [
  {
    id: "open_loop_resurface",
    description: "After an open loop was resurfaced and no follow-up reflection",
    minIntervalHours: 48,
    enabled: true,
  },
  {
    id: "return_after_silence",
    description: "After meaningful silence with prior archive attachment",
    minIntervalHours: 72,
    enabled: true,
  },
  {
    id: "emotional_continuity",
    description: "When continuity line was shown and user revisited archive",
    minIntervalHours: 96,
    enabled: true,
  },
];

export function getQuietTrigger(id: QuietNotificationKind): QuietNotificationTrigger | undefined {
  return QUIET_NOTIFICATION_TRIGGERS.find((row) => row.id === id);
}

export function buildQuietNotificationPayload(id: QuietNotificationKind): {
  title: string;
  body: string;
  tag: string;
} {
  const copy = NOTIFICATION_COPY[id];
  return {
    title: copy.title,
    body: copy.body,
    tag: `voicememory-quiet-${id}`,
  };
}
