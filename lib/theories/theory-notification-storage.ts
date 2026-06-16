import { recordNotificationCreated } from "@/lib/theories/theory-notification-lifecycle";
import type { TheoryNotification } from "@/types/theory-notification";

export const THEORY_NOTIFICATIONS_KEY = "voicememory_theory_notifications";

const MAX_NOTIFICATIONS = 200;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `tn-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function normalize(raw: unknown): TheoryNotification | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.id !== "string" || typeof row.theoryId !== "string") return null;
  if (typeof row.type !== "string" || typeof row.title !== "string") return null;
  if (typeof row.body !== "string" || typeof row.createdAt !== "string") return null;
  if (typeof row.importance !== "string" || typeof row.relatedRoute !== "string") {
    return null;
  }
  if (typeof row.evidenceSummary !== "string" || typeof row.dedupeKey !== "string") {
    return null;
  }

  return {
    id: row.id,
    theoryId: row.theoryId,
    type: row.type as TheoryNotification["type"],
    title: row.title,
    body: row.body,
    createdAt: row.createdAt,
    readAt: typeof row.readAt === "string" ? row.readAt : undefined,
    importance: row.importance as TheoryNotification["importance"],
    relatedRoute: row.relatedRoute as TheoryNotification["relatedRoute"],
    evidenceSummary: row.evidenceSummary,
    confidenceDelta:
      typeof row.confidenceDelta === "number" ? row.confidenceDelta : undefined,
    dedupeKey: row.dedupeKey,
  };
}

export function readTheoryNotifications(): TheoryNotification[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(THEORY_NOTIFICATIONS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((n): n is TheoryNotification => Boolean(n))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  } catch {
    return [];
  }
}

export function writeTheoryNotifications(notifications: TheoryNotification[]): void {
  const store = getStorage();
  if (!store) return;
  store.setItem(
    THEORY_NOTIFICATIONS_KEY,
    JSON.stringify(notifications.slice(0, MAX_NOTIFICATIONS)),
  );
}

export function appendTheoryNotifications(incoming: TheoryNotification[]): TheoryNotification[] {
  if (incoming.length === 0) return readTheoryNotifications();

  const existing = readTheoryNotifications();
  const seen = new Set(existing.map((n) => n.dedupeKey));
  const merged = [...existing];

  for (const notification of incoming) {
    if (seen.has(notification.dedupeKey)) continue;
    seen.add(notification.dedupeKey);
    merged.push(notification);
    recordNotificationCreated(notification);
  }

  merged.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  writeTheoryNotifications(merged);
  dispatchNotificationsChanged();
  return merged;
}

function dispatchNotificationsChanged(): void {
  if (typeof window === "undefined" || typeof window.dispatchEvent !== "function") {
    return;
  }
  window.dispatchEvent(new Event("voicememory-theory-notifications"));
}

export function countUnreadTheoryNotifications(): number {
  return readTheoryNotifications().filter((n) => !n.readAt).length;
}

export function markTheoryNotificationRead(id: string): TheoryNotification | null {
  const all = readTheoryNotifications();
  let updated: TheoryNotification | null = null;
  const now = new Date().toISOString();
  const next = all.map((n) => {
    if (n.id !== id) return n;
    updated = { ...n, readAt: n.readAt ?? now };
    return updated;
  });
  writeTheoryNotifications(next);
  dispatchNotificationsChanged();
  return updated;
}

export function markAllTheoryNotificationsRead(): void {
  const now = new Date().toISOString();
  const next = readTheoryNotifications().map((n) => ({
    ...n,
    readAt: n.readAt ?? now,
  }));
  writeTheoryNotifications(next);
  dispatchNotificationsChanged();
}

export function clearTheoryNotificationsForEval(): void {
  getStorage()?.removeItem(THEORY_NOTIFICATIONS_KEY);
}
