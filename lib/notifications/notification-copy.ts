/** Quiet notification copy — no guilt trips or productivity framing. */

export const NOTIFICATION_COPY = {
  open_loop_resurface: {
    title: "A thread you kept open",
    body: "Your words are still there when you want to reflect.",
  },
  return_after_silence: {
    title: "Your archive is here",
    body: "A few saved words pick up where you left off — only if you want to.",
  },
  emotional_continuity: {
    title: "Something familiar returned",
    body: "In your own phrasing — not a reminder to perform.",
  },
} as const;

export type QuietNotificationKind = keyof typeof NOTIFICATION_COPY;
