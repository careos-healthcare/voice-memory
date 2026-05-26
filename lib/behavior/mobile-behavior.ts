import { LAUNCH_EVENTS, readLocalEvents } from "@/lib/local-analytics";
import { BEHAVIOR_EVENTS } from "@/lib/behavior/observation";
import { isPWA } from "@/lib/mobile/platform";
import { hoursBetween } from "@/lib/behavior/helpers";
import type { MobileBehaviorRow } from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";

function isMobileSession(events: LocalAnalyticsEvent[]): boolean {
  return events.some(
    (e) =>
      e.name === BEHAVIOR_EVENTS.sessionDeviceContext && e.meta?.mobile === "1",
  );
}

function reflectionCountOnMobile(events: LocalAnalyticsEvent[], total: number): number {
  if (!isMobileSession(events)) return 0;
  return total;
}

export function computeMobileBehavior(
  events: LocalAnalyticsEvent[],
  entries: JournalEntry[],
): MobileBehaviorRow[] {
  const mobileCtx = isMobileSession(events);
  const installed = isPWA() || events.some((e) => e.name === BEHAVIOR_EVENTS.installAccepted);
  const installShown = events.filter((e) => e.name === BEHAVIOR_EVENTS.installPromptShown).length;
  const secondReflection = events.some((e) => e.name === LAUNCH_EVENTS.secondReflectionCreated);

  let installToSecondHours: number | null = null;
  const installAt = events.find((e) => e.name === BEHAVIOR_EVENTS.installAccepted)?.at;
  const secondAt = events.find((e) => e.name === LAUNCH_EVENTS.secondReflectionCreated)?.at;
  if (installAt && secondAt) {
    installToSecondHours = Math.round(hoursBetween(installAt, secondAt));
  }

  const notificationPermission =
    typeof window !== "undefined" && "Notification" in window
      ? Notification.permission
      : "unsupported";

  const returnsAfterSilence = events.filter((e) => e.name === "return_after_silence").length;

  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  let longSessions = 0;
  let shortSessions = 0;
  const dayBuckets = new Map<string, number>();
  for (const entry of sorted) {
    const day = entry.createdAt.slice(0, 10);
    dayBuckets.set(day, (dayBuckets.get(day) ?? 0) + 1);
  }
  for (const count of dayBuckets.values()) {
    if (count >= 2) longSessions += 1;
    else shortSessions += 1;
  }

  return [
    {
      label: "Mobile session logged",
      value: mobileCtx ? "Yes" : "No / unknown",
      plain: mobileCtx
        ? "At least one session on this device was tagged as mobile."
        : "No mobile session tag yet — open on a phone and refresh this page.",
    },
    {
      label: "Reflections (device total)",
      value: String(entries.length),
      plain:
        mobileCtx && entries.length > 0
          ? `${reflectionCountOnMobile(events, entries.length)} reflections while mobile context was logged (same archive).`
          : "Reflection count is for the whole archive on this device.",
    },
    {
      label: "Installed (PWA)",
      value: installed ? "Yes" : "No",
      plain: installed
        ? "Running installed or install was accepted — check second reflection timing below."
        : "Not installed as PWA on this device yet.",
    },
    {
      label: "Install prompt → second reflection",
      value:
        installToSecondHours !== null
          ? `~${installToSecondHours}h`
          : installShown > 0
            ? "Pending"
            : "—",
      plain:
        installToSecondHours !== null
          ? `Second reflection arrived about ${installToSecondHours} hours after install accept.`
          : installShown > 0 && !secondReflection
            ? "Install prompt was shown but second reflection has not happened yet."
            : "No install-to-second-reflection path logged yet.",
    },
    {
      label: "Notification permission",
      value: notificationPermission,
      plain:
        notificationPermission === "granted"
          ? `Permission granted; ${returnsAfterSilence} return-after-silence events on this device.`
          : notificationPermission === "denied"
            ? "Notifications denied — silent push path will not fire."
            : "Notifications not decided or unsupported in this browser.",
    },
    {
      label: "Session density",
      value: `${longSessions} multi-reflection days / ${shortSessions} single`,
      plain:
        longSessions > shortSessions
          ? "Some days include multiple reflections — longer emotional sessions."
          : "Most active days have a single reflection — short, focused sessions.",
    },
  ];
}
