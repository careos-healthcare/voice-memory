import type {
  PushVerificationCheck,
  PushVerificationCheckId,
  PushVerificationCheckStatus,
  PushVerificationEvent,
  PushVerificationReport,
  PushVerificationScreenEvent,
  PushVerificationStore,
} from "@/types/push-verification";

export const PUSH_VERIFICATION_STORE_KEY = "voicememory_push_verification_v1";
export const PUSH_VERIFICATION_OPEN_PENDING_KEY =
  "voicememory_push_verify_open_pending";

export const PUSH_VERIFICATION_DEFAULT_TARGET = "/record";

const CHECK_LABELS: Record<PushVerificationCheckId, string> = {
  permission_requested: "Permission requested",
  permission_granted: "Permission granted",
  notification_delivered: "Notification delivered",
  notification_tapped: "Notification tapped",
  correct_screen_opened: "Correct screen opened",
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function emptyStore(): PushVerificationStore {
  return {
    permissionRequestedAt: null,
    permissionGrantedAt: null,
    permissionDeniedAt: null,
    lastNotificationSent: null,
    lastNotificationDelivered: null,
    lastNotificationOpened: null,
    lastScreenOpened: null,
  };
}

export function readPushVerificationStore(): PushVerificationStore {
  if (!isBrowser()) return emptyStore();
  try {
    const raw = localStorage.getItem(PUSH_VERIFICATION_STORE_KEY);
    if (!raw) return emptyStore();
    return { ...emptyStore(), ...(JSON.parse(raw) as PushVerificationStore) };
  } catch {
    return emptyStore();
  }
}

export function writePushVerificationStore(store: PushVerificationStore): void {
  if (!isBrowser()) return;
  localStorage.setItem(PUSH_VERIFICATION_STORE_KEY, JSON.stringify(store));
}

function patchStore(patch: Partial<PushVerificationStore>): PushVerificationStore {
  const next = { ...readPushVerificationStore(), ...patch };
  writePushVerificationStore(next);
  return next;
}

export function clearPushVerificationStore(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PUSH_VERIFICATION_STORE_KEY);
  sessionStorage.removeItem(PUSH_VERIFICATION_OPEN_PENDING_KEY);
}

function newEvent(
  targetPath: string,
  title: string,
  tag = "voicememory-push-verify",
): PushVerificationEvent {
  return {
    id: crypto.randomUUID(),
    at: new Date().toISOString(),
    title,
    targetPath,
    tag,
  };
}

export function recordPushPermissionRequested(): void {
  patchStore({
    permissionRequestedAt: new Date().toISOString(),
  });
}

export function recordPushPermissionGranted(): void {
  patchStore({
    permissionGrantedAt: new Date().toISOString(),
    permissionDeniedAt: null,
  });
}

export function recordPushPermissionDenied(): void {
  patchStore({
    permissionDeniedAt: new Date().toISOString(),
  });
}

export function recordPushNotificationSent(event: PushVerificationEvent): void {
  patchStore({
    lastNotificationSent: event,
    lastNotificationDelivered: null,
    lastNotificationOpened: null,
    lastScreenOpened: null,
  });
}

export function recordPushNotificationDelivered(
  event: PushVerificationEvent,
): void {
  patchStore({ lastNotificationDelivered: event });
}

export function recordPushNotificationOpened(event: PushVerificationEvent): void {
  patchStore({ lastNotificationOpened: event });
  if (!isBrowser()) return;
  sessionStorage.setItem(
    PUSH_VERIFICATION_OPEN_PENDING_KEY,
    JSON.stringify({ targetPath: event.targetPath, openedAt: event.at }),
  );
}

export function recordPushVerificationScreenOpened(
  path: string,
  targetPath: string,
): PushVerificationScreenEvent {
  const normalizedPath = path.split("?")[0] ?? path;
  const normalizedTarget = targetPath.split("?")[0] ?? targetPath;
  const matchesTarget =
    normalizedPath === normalizedTarget ||
    normalizedPath.startsWith(`${normalizedTarget}/`);

  const row: PushVerificationScreenEvent = {
    at: new Date().toISOString(),
    path: normalizedPath,
    targetPath: normalizedTarget,
    matchesTarget,
  };
  patchStore({ lastScreenOpened: row });
  return row;
}

/** Complete open flow after navigation — call on route change. */
export function completePushVerificationOpenPending(currentPath: string): void {
  if (!isBrowser()) return;
  const raw = sessionStorage.getItem(PUSH_VERIFICATION_OPEN_PENDING_KEY);
  if (!raw) return;
  try {
    const pending = JSON.parse(raw) as { targetPath: string };
    recordPushVerificationScreenOpened(currentPath, pending.targetPath);
  } finally {
    sessionStorage.removeItem(PUSH_VERIFICATION_OPEN_PENDING_KEY);
  }
}

export function getBrowserNotificationPermission(): NotificationPermission | "unsupported" {
  if (!isBrowser() || !("Notification" in window)) return "unsupported";
  return Notification.permission;
}

export function isPushVerificationApiAvailable(): boolean {
  return getBrowserNotificationPermission() !== "unsupported";
}

export async function requestPushVerificationPermission(): Promise<
  NotificationPermission | "unsupported"
> {
  if (!isPushVerificationApiAvailable()) return "unsupported";
  recordPushPermissionRequested();
  const result = await Notification.requestPermission();
  if (result === "granted") recordPushPermissionGranted();
  if (result === "denied") recordPushPermissionDenied();
  return result;
}

export type SendPushVerificationResult =
  | { ok: true; event: PushVerificationEvent }
  | { ok: false; reason: string };

/**
 * Send a real browser notification for founder verification (dev / internal).
 * Requires granted permission; does not fake delivery.
 */
export function sendPushVerificationNotification(
  targetPath: string = PUSH_VERIFICATION_DEFAULT_TARGET,
): SendPushVerificationResult {
  if (!isPushVerificationApiAvailable()) {
    return { ok: false, reason: "Notifications API not available in this browser." };
  }
  if (Notification.permission !== "granted") {
    return { ok: false, reason: "Notification permission not granted." };
  }

  const event = newEvent(
    targetPath,
    "ArchiveMe — tap to verify push",
    "voicememory-push-verify",
  );
  recordPushNotificationSent(event);

  try {
    const notification = new Notification(event.title, {
      body: `Opens ${targetPath} when tapped.`,
      tag: event.tag,
      data: { targetPath, verificationId: event.id },
    });

    notification.onshow = () => {
      recordPushNotificationDelivered(event);
    };

    notification.onclick = () => {
      recordPushNotificationOpened(event);
      window.focus();
      notification.close();
      const dest = targetPath.startsWith("/") ? targetPath : `/${targetPath}`;
      if (window.location.pathname !== dest.split("?")[0]) {
        window.location.assign(dest);
      } else {
        recordPushVerificationScreenOpened(window.location.pathname, targetPath);
        sessionStorage.removeItem(PUSH_VERIFICATION_OPEN_PENDING_KEY);
      }
    };

    notification.onerror = () => {
      /* delivery not confirmed */
    };

    if (typeof notification.onshow === "undefined") {
      recordPushNotificationDelivered(event);
    }

    return { ok: true, event };
  } catch (e) {
    return {
      ok: false,
      reason: e instanceof Error ? e.message : "Failed to show notification",
    };
  }
}

function checkStatus(pass: boolean, fail: boolean): PushVerificationCheckStatus {
  if (pass) return "PASSING";
  if (fail) return "FAILING";
  return "UNKNOWN";
}

function buildCheck(
  id: PushVerificationCheckId,
  store: PushVerificationStore,
  permission: PushVerificationReport["permission"],
): PushVerificationCheck {
  switch (id) {
    case "permission_requested":
      return {
        id,
        label: CHECK_LABELS[id],
        status: checkStatus(Boolean(store.permissionRequestedAt), false),
        detail: store.permissionRequestedAt
          ? `Requested at ${store.permissionRequestedAt}`
          : "Call Request permission on the verification page.",
      };
    case "permission_granted":
      return {
        id,
        label: CHECK_LABELS[id],
        status: checkStatus(
          permission === "granted" || Boolean(store.permissionGrantedAt),
          permission === "denied" || Boolean(store.permissionDeniedAt),
        ),
        detail:
          permission === "granted"
            ? "Browser permission is granted."
            : permission === "denied"
              ? "Permission denied — enable in system settings."
              : store.permissionGrantedAt
                ? `Granted at ${store.permissionGrantedAt}`
                : "Grant notification permission first.",
      };
    case "notification_delivered":
      return {
        id,
        label: CHECK_LABELS[id],
        status: checkStatus(Boolean(store.lastNotificationDelivered), false),
        detail: store.lastNotificationDelivered
          ? `Delivered ${store.lastNotificationDelivered.at} · ${store.lastNotificationDelivered.title}`
          : store.lastNotificationSent
            ? `Sent ${store.lastNotificationSent.at} — awaiting onshow`
            : "Send a test notification after permission is granted.",
      };
    case "notification_tapped":
      return {
        id,
        label: CHECK_LABELS[id],
        status: checkStatus(Boolean(store.lastNotificationOpened), false),
        detail: store.lastNotificationOpened
          ? `Opened ${store.lastNotificationOpened.at} · target ${store.lastNotificationOpened.targetPath}`
          : "Tap the test notification when it appears.",
      };
    case "correct_screen_opened":
      return {
        id,
        label: CHECK_LABELS[id],
        status: checkStatus(
          Boolean(store.lastScreenOpened?.matchesTarget),
          Boolean(store.lastScreenOpened && !store.lastScreenOpened.matchesTarget),
        ),
        detail: store.lastScreenOpened
          ? store.lastScreenOpened.matchesTarget
            ? `Matched ${store.lastScreenOpened.targetPath} at ${store.lastScreenOpened.at}`
            : `Opened ${store.lastScreenOpened.path} but expected ${store.lastScreenOpened.targetPath}`
          : "After tap, app should land on the notification target route.",
      };
    default:
      return { id, label: id, status: "UNKNOWN", detail: "" };
  }
}

export function buildPushVerificationReport(): PushVerificationReport {
  const store = readPushVerificationStore();
  const permission = isBrowser()
    ? getBrowserNotificationPermission()
    : "unavailable";
  const checks = (
    Object.keys(CHECK_LABELS) as PushVerificationCheckId[]
  ).map((id) => buildCheck(id, store, permission));

  const unknownCount = checks.filter((c) => c.status === "UNKNOWN").length;
  const passingCount = checks.filter((c) => c.status === "PASSING").length;
  const failingCount = checks.filter((c) => c.status === "FAILING").length;

  return {
    generatedAt: new Date().toISOString(),
    store,
    checks,
    permission,
    pushApiAvailable: isBrowser() && isPushVerificationApiAvailable(),
    unknownCount,
    passingCount,
    failingCount,
  };
}

export const PUSH_VERIFICATION_CHECK_IDS = Object.keys(
  CHECK_LABELS,
) as PushVerificationCheckId[];
