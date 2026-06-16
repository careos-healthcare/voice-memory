import type {
  ArchiveMovementEvent,
  ArchiveMovementEventName,
  ArchiveMovementRecord,
  ArchiveMovementUpdate,
} from "@/types/archive-movement";

export const ARCHIVE_UPDATES_STORAGE_KEY = "voicememory_archive_updates";

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readUpdates(): ArchiveMovementRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(ARCHIVE_UPDATES_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ArchiveMovementRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeUpdates(records: ArchiveMovementRecord[]): void {
  getStorage()?.setItem(
    ARCHIVE_UPDATES_STORAGE_KEY,
    JSON.stringify(records.slice(-120)),
  );
}

function readEvents(): ArchiveMovementEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(`${ARCHIVE_UPDATES_STORAGE_KEY}_events`);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ArchiveMovementEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEvents(events: ArchiveMovementEvent[]): void {
  getStorage()?.setItem(
    `${ARCHIVE_UPDATES_STORAGE_KEY}_events`,
    JSON.stringify(events.slice(-400)),
  );
}

export function readArchiveMovementRecords(): ArchiveMovementRecord[] {
  return readUpdates();
}

export function readLatestArchiveMovement(): ArchiveMovementRecord | null {
  const records = readUpdates();
  return records.length > 0 ? records[records.length - 1]! : null;
}

export function clearArchiveMovementForEval(): void {
  const store = getStorage();
  store?.removeItem(ARCHIVE_UPDATES_STORAGE_KEY);
  store?.removeItem(`${ARCHIVE_UPDATES_STORAGE_KEY}_events`);
}

export function persistArchiveMovement(
  update: ArchiveMovementUpdate,
  meta?: { entryId?: string; reflectionCount?: number },
): ArchiveMovementRecord {
  const record: ArchiveMovementRecord = {
    ...update,
    entryId: meta?.entryId,
    reflectionCount: meta?.reflectionCount ?? 0,
  };
  const records = readUpdates();
  const last = records[records.length - 1];
  if (last?.id === update.id) return last;
  records.push(record);
  writeUpdates(records);
  return record;
}

function trackEvent(
  name: ArchiveMovementEventName,
  update: ArchiveMovementUpdate,
): void {
  const events = readEvents();
  events.push({
    name,
    at: new Date().toISOString(),
    movementId: update.id,
    kind: update.kind,
  });
  writeEvents(events);
}

export function trackArchiveUpdateSeen(update: ArchiveMovementUpdate): void {
  const events = readEvents();
  const seen = events.some(
    (e) => e.name === "archive_update_seen" && e.movementId === update.id,
  );
  if (seen) return;
  trackEvent("archive_update_seen", update);
}

export function trackArchiveUpdateExpanded(update: ArchiveMovementUpdate): void {
  trackEvent("archive_update_expanded", update);
}

export function readArchiveMovementEvents(): ArchiveMovementEvent[] {
  return readEvents();
}

export function countArchiveMovementEvents(name: ArchiveMovementEventName): number {
  return readEvents().filter((e) => e.name === name).length;
}
