import { trackLocalEvent } from "@/lib/local-analytics";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import { withTrackingGuard } from "@/lib/tracking/sync-guard";

export const SESSION_RETENTION_EVENTS = {
  firstVisit: "first_visit",
  firstReflectionSaved: "first_reflection_saved",
  secondSessionStarted: "second_session_started",
  day2Return: "day_2_return",
  firstCallbackSeen: "first_callback_seen",
  firstCallbackOpened: "first_callback_opened",
  reflectionAfterCallback: "reflection_after_callback",
} as const;

export type SessionRetentionEvent =
  (typeof SESSION_RETENTION_EVENTS)[keyof typeof SESSION_RETENTION_EVENTS];

const ONCE_KEY = "voicememory_session_retention_once";
const SESSION_COUNT_KEY = "voicememory_app_session_count";
const REFLECTION_AFTER_CALLBACK_KEY = "voicememory_reflection_after_callback_pending";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readOnceFlags(): Record<string, boolean> {
  if (!isBrowser()) return {};
  try {
    const raw = localStorage.getItem(ONCE_KEY);
    if (!raw) return {};
    return JSON.parse(raw) as Record<string, boolean>;
  } catch {
    return {};
  }
}

function writeOnceFlag(event: SessionRetentionEvent): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  withTrackingGuard(() => {
    const flags = readOnceFlags();
    if (flags[event]) return;
    flags[event] = true;
    localStorage.setItem(ONCE_KEY, JSON.stringify(flags));
    trackLocalEvent(event, { schema: "session_retention_v1" });
  });
}

/** Count discrete app sessions (tab loads) for session-2 measurement. */
export function markAppSessionStarted(): number {
  if (!isBrowser()) return 0;
  const count = Number(sessionStorage.getItem(SESSION_COUNT_KEY) ?? "0") + 1;
  sessionStorage.setItem(SESSION_COUNT_KEY, String(count));
  if (count === 1) {
    writeOnceFlag(SESSION_RETENTION_EVENTS.firstVisit);
  }
  if (count >= 2) {
    writeOnceFlag(SESSION_RETENTION_EVENTS.secondSessionStarted);
  }
  return count;
}

export function observeSessionFirstReflectionSaved(): void {
  writeOnceFlag(SESSION_RETENTION_EVENTS.firstReflectionSaved);
}

export function observeSessionDay2Return(meta?: Record<string, string>): void {
  withTrackingGuard(() => {
    if (!isBrowser() || isSideEffectBlocked()) return;
    const flags = readOnceFlags();
    if (flags[SESSION_RETENTION_EVENTS.day2Return]) return;
    flags[SESSION_RETENTION_EVENTS.day2Return] = true;
    localStorage.setItem(ONCE_KEY, JSON.stringify(flags));
    trackLocalEvent(SESSION_RETENTION_EVENTS.day2Return, {
      schema: "session_retention_v1",
      ...meta,
    });
  });
}

export function observeSessionFirstCallbackSeen(meta?: Record<string, string>): void {
  withTrackingGuard(() => {
    writeOnceFlag(SESSION_RETENTION_EVENTS.firstCallbackSeen);
    if (meta) trackLocalEvent(SESSION_RETENTION_EVENTS.firstCallbackSeen, meta);
  });
}

export function observeSessionFirstCallbackOpened(meta?: Record<string, string>): void {
  withTrackingGuard(() => {
    writeOnceFlag(SESSION_RETENTION_EVENTS.firstCallbackOpened);
    if (meta) trackLocalEvent(SESSION_RETENTION_EVENTS.firstCallbackOpened, meta);
  });
}

export function markReflectionAfterCallbackPending(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(REFLECTION_AFTER_CALLBACK_KEY, "1");
}

export function observeSessionReflectionAfterCallbackIfPending(): void {
  if (!isBrowser()) return;
  if (sessionStorage.getItem(REFLECTION_AFTER_CALLBACK_KEY) !== "1") return;
  sessionStorage.removeItem(REFLECTION_AFTER_CALLBACK_KEY);
  writeOnceFlag(SESSION_RETENTION_EVENTS.reflectionAfterCallback);
}
