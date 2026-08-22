import { getOrCreateDeviceId, readDeviceId } from "@/lib/sync/device-id";
import { getEntry } from "@/lib/storage";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import type { SyncEmotionalContinuityRecord } from "@/types/sync-continuity";

const STORAGE_KEY = "voicememory_emotional_continuity";
const PENDING_CARRYOVER_KEY = "voicememory_carryover_pending";
const CARRYOVER_SHOWN_KEY = "voicememory_carryover_shown_at";

const CARRYOVER_FRESH_MS = 72 * 60 * 60 * 1000;
const OLDER_REFLECTION_DAYS = 14;

export const CARRYOVER_COPY = {
  leftOffHere: "You left off here.",
  wereRevisiting: "You were revisiting this.",
  openOnOtherDevice: "This was still open on another device.",
  continueWhereStopped: "You can continue from where you stopped.",
} as const;

export const ACCOUNT_CONTINUITY_COPY = {
  archiveContinues: "Encrypted backup can continue on another device.",
  leftOffOlder: "You left off with an older reflection.",
} as const;

export type RevisitSourceKind =
  | "prior_view"
  | "memory_note"
  | "resurfacing"
  | "revisitation"
  | "bookmark"
  | "thread"
  | "timeline"
  | "memory"
  | "monthly"
  | string;

export interface CrossDeviceEmotionalState {
  lastOpenedEntryId?: string;
  lastOpenedAt?: string;
  lastRevisitSource?: string;
  lastRevisitEntryId?: string;
  lastRevisitAt?: string;
  lastFollowUpPrompt?: {
    id: string;
    text: string;
    noteId?: string;
    entryId?: string;
  };
  lastFollowUpAt?: string;
  lastUnfinishedContinuation?: {
    promptId: string;
    noteId?: string;
    entryId?: string;
  };
  lastUnfinishedAt?: string;
  recentBookmarkEntryId?: string;
  recentBookmarkAt?: string;
  lastMemoryLine?: {
    noteId: string;
    noteText?: string;
    entryId?: string;
  };
  lastMemoryLineAt?: string;
  lastThenVsNow?: {
    noteId: string;
    pastEntryId?: string;
    entryId?: string;
  };
  lastThenVsNowAt?: string;
}

export interface HomepageCarryover {
  line: string;
  entryId?: string;
  href?: string;
}

export interface AccountContinuityStatus {
  archiveContinuesLine: string | null;
  leftOffLine: string | null;
  lastBackedUpLine: string | null;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function nowIso(): string {
  return new Date().toISOString();
}

function parseTime(iso: string | undefined): number {
  if (!iso) return 0;
  const time = new Date(iso).getTime();
  return Number.isFinite(time) ? time : 0;
}

function isFresh(iso: string | undefined, maxAgeMs: number = CARRYOVER_FRESH_MS): boolean {
  const time = parseTime(iso);
  if (!time) return false;
  return Date.now() - time <= maxAgeMs;
}

function readRecord(): SyncEmotionalContinuityRecord | null {
  if (!isBrowser()) return null;

  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as SyncEmotionalContinuityRecord;
  } catch {
    return null;
  }
}

function writeRecord(state: CrossDeviceEmotionalState): SyncEmotionalContinuityRecord {
  const record: SyncEmotionalContinuityRecord = {
    state,
    updatedAt: nowIso(),
    sourceDeviceId: getOrCreateDeviceId(),
  };

  if (isBrowser()) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
  }

  return record;
}

function patchState(patch: Partial<CrossDeviceEmotionalState>): SyncEmotionalContinuityRecord {
  const current: CrossDeviceEmotionalState = readRecord()?.state ?? {};
  return writeRecord({ ...current, ...patch });
}

export function readEmotionalContinuity(): SyncEmotionalContinuityRecord | null {
  return readRecord();
}

export function readEmotionalContinuityState(): CrossDeviceEmotionalState | null {
  return readRecord()?.state ?? null;
}

export function buildEmotionalContinuityForSync(): SyncEmotionalContinuityRecord | null {
  return readRecord();
}

export function applyEmotionalContinuityFromSync(
  record: SyncEmotionalContinuityRecord | null | undefined,
): void {
  if (!isBrowser() || !record) return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
}

export function mergeEmotionalContinuityRecords(
  local: SyncEmotionalContinuityRecord | null | undefined,
  remote: SyncEmotionalContinuityRecord | null | undefined,
  localDeviceId: string,
): SyncEmotionalContinuityRecord | null {
  if (!local && !remote) return null;
  if (!local) return remote ?? null;
  if (!remote) return local;

  const localTime = parseTime(local.updatedAt);
  const remoteTime = parseTime(remote.updatedAt);

  if (localTime > remoteTime) return local;
  if (remoteTime > localTime) return remote;

  if (local.sourceDeviceId === localDeviceId) return local;
  if (remote.sourceDeviceId === localDeviceId) return local;
  return local;
}

export function markPendingHomepageCarryover(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(PENDING_CARRYOVER_KEY, "1");
}

export function consumePendingHomepageCarryover(): boolean {
  if (!isBrowser()) return false;
  const pending = sessionStorage.getItem(PENDING_CARRYOVER_KEY) === "1";
  if (pending) sessionStorage.removeItem(PENDING_CARRYOVER_KEY);
  return pending;
}

export function markPendingCarryoverAfterRemoteMerge(
  remote: SyncEmotionalContinuityRecord | null | undefined,
): void {
  if (!remote) return;
  const localDeviceId = readDeviceId() ?? getOrCreateDeviceId();
  if (remote.sourceDeviceId === localDeviceId) return;
  if (!isFresh(remote.updatedAt)) return;
  if (!hasMeaningfulContinuity(remote.state)) return;
  markPendingHomepageCarryover();
}

function hasMeaningfulContinuity(state: CrossDeviceEmotionalState): boolean {
  return Boolean(
    state.lastOpenedEntryId ||
      state.lastRevisitEntryId ||
      state.lastUnfinishedContinuation ||
      state.lastFollowUpPrompt ||
      state.recentBookmarkEntryId ||
      state.lastMemoryLine ||
      state.lastThenVsNow,
  );
}

function entryExists(entryId: string | undefined): boolean {
  if (!entryId) return false;
  return Boolean(getEntry(entryId));
}

function isOlderReflection(entryId: string | undefined): boolean {
  if (!entryId) return false;
  const entry = getEntry(entryId);
  if (!entry) return false;
  return daysBetweenKeys(toDayKey(entry.createdAt), todayKey()) >= OLDER_REFLECTION_DAYS;
}

function carryoverAlreadyShown(recordUpdatedAt: string): boolean {
  if (!isBrowser()) return true;
  const shownAt = sessionStorage.getItem(CARRYOVER_SHOWN_KEY);
  return shownAt === recordUpdatedAt;
}

function markCarryoverShown(recordUpdatedAt: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(CARRYOVER_SHOWN_KEY, recordUpdatedAt);
}

function fromOtherDevice(record: SyncEmotionalContinuityRecord): boolean {
  const localDeviceId = readDeviceId() ?? getOrCreateDeviceId();
  return record.sourceDeviceId !== localDeviceId;
}

export function buildHomepageCarryoverLine(options?: {
  requirePending?: boolean;
}): HomepageCarryover | null {
  if (options?.requirePending && !consumePendingHomepageCarryover()) {
    return null;
  }

  const record = readRecord();
  if (!record || !isFresh(record.updatedAt)) return null;
  if (carryoverAlreadyShown(record.updatedAt)) return null;

  const state = record.state;
  const otherDevice = fromOtherDevice(record);

  const candidates: Array<{ score: number; carryover: HomepageCarryover }> = [];

  if (
    state.lastUnfinishedContinuation &&
    isFresh(state.lastUnfinishedAt) &&
    (state.lastUnfinishedContinuation.entryId
      ? entryExists(state.lastUnfinishedContinuation.entryId)
      : true)
  ) {
    candidates.push({
      score: 100,
      carryover: {
        line: CARRYOVER_COPY.continueWhereStopped,
        entryId: state.lastUnfinishedContinuation.entryId,
        href: state.lastUnfinishedContinuation.entryId
          ? `/entry/${state.lastUnfinishedContinuation.entryId}`
          : "/",
      },
    });
  }

  if (
    state.lastFollowUpPrompt &&
    isFresh(state.lastFollowUpAt) &&
    state.lastFollowUpPrompt.text.trim().length >= 8
  ) {
    candidates.push({
      score: 95,
      carryover: {
        line: CARRYOVER_COPY.continueWhereStopped,
        entryId: state.lastFollowUpPrompt.entryId,
        href: state.lastFollowUpPrompt.entryId
          ? `/entry/${state.lastFollowUpPrompt.entryId}`
          : "/",
      },
    });
  }

  if (
    state.lastRevisitEntryId &&
    isFresh(state.lastRevisitAt) &&
    entryExists(state.lastRevisitEntryId)
  ) {
    candidates.push({
      score: otherDevice ? 88 : 80,
      carryover: {
        line: otherDevice
          ? CARRYOVER_COPY.openOnOtherDevice
          : CARRYOVER_COPY.wereRevisiting,
        entryId: state.lastRevisitEntryId,
        href: `/entry/${state.lastRevisitEntryId}`,
      },
    });
  }

  if (
    state.lastOpenedEntryId &&
    isFresh(state.lastOpenedAt) &&
    entryExists(state.lastOpenedEntryId) &&
    state.lastOpenedEntryId !== state.lastRevisitEntryId
  ) {
    candidates.push({
      score: otherDevice ? 72 : 70,
      carryover: {
        line: otherDevice
          ? CARRYOVER_COPY.openOnOtherDevice
          : CARRYOVER_COPY.leftOffHere,
        entryId: state.lastOpenedEntryId,
        href: `/entry/${state.lastOpenedEntryId}`,
      },
    });
  }

  if (
    state.recentBookmarkEntryId &&
    isFresh(state.recentBookmarkAt) &&
    entryExists(state.recentBookmarkEntryId)
  ) {
    candidates.push({
      score: 65,
      carryover: {
        line: CARRYOVER_COPY.wereRevisiting,
        entryId: state.recentBookmarkEntryId,
        href: `/entry/${state.recentBookmarkEntryId}`,
      },
    });
  }

  const best = candidates.sort((a, b) => b.score - a.score)[0];
  if (!best) {
    if (options?.requirePending) return null;
    return null;
  }

  if (!options?.requirePending && !otherDevice && best.score < 80) {
    return null;
  }

  markCarryoverShown(record.updatedAt);
  return best.carryover;
}

export function buildAccountContinuityStatus(input: {
  signedIn: boolean;
  lastBackupAt: string | null;
}): AccountContinuityStatus {
  const record = readRecord();
  const lastBackedUpLine = input.lastBackupAt
    ? `Last backed up ${formatQuietDate(input.lastBackupAt)}.`
    : null;

  if (!input.signedIn) {
    return {
      archiveContinuesLine: null,
      leftOffLine: null,
      lastBackedUpLine,
    };
  }

  const archiveContinuesLine = ACCOUNT_CONTINUITY_COPY.archiveContinues;

  let leftOffLine: string | null = null;
  const entryId =
    record?.state.lastRevisitEntryId ?? record?.state.lastOpenedEntryId ?? null;

  if (entryId && entryExists(entryId) && isOlderReflection(entryId)) {
    leftOffLine = ACCOUNT_CONTINUITY_COPY.leftOffOlder;
  }

  return {
    archiveContinuesLine,
    leftOffLine,
    lastBackedUpLine,
  };
}

function formatQuietDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: "long",
      day: "numeric",
    });
  } catch {
    return "recently";
  }
}

export function recordLastOpenedEntry(entryId: string): void {
  if (!entryId) return;
  patchState({
    lastOpenedEntryId: entryId,
    lastOpenedAt: nowIso(),
  });
}

export function recordRevisitContext(
  entryId: string,
  source: RevisitSourceKind,
): void {
  if (!entryId) return;
  patchState({
    lastRevisitEntryId: entryId,
    lastRevisitSource: source,
    lastRevisitAt: nowIso(),
  });

  if (source === "bookmark") {
    patchState({
      recentBookmarkEntryId: entryId,
      recentBookmarkAt: nowIso(),
    });
  }
}

export function recordFollowUpPrompt(input: {
  id: string;
  text: string;
  noteId?: string;
  entryId?: string;
}): void {
  patchState({
    lastFollowUpPrompt: {
      id: input.id,
      text: input.text,
      noteId: input.noteId,
      entryId: input.entryId,
    },
    lastFollowUpAt: nowIso(),
  });
}

export function recordUnfinishedContinuation(input: {
  promptId: string;
  noteId?: string;
  entryId?: string;
}): void {
  patchState({
    lastUnfinishedContinuation: {
      promptId: input.promptId,
      noteId: input.noteId,
      entryId: input.entryId,
    },
    lastUnfinishedAt: nowIso(),
  });
}

export function recordMemoryLineClicked(input: {
  noteId: string;
  noteText?: string;
  entryId?: string;
}): void {
  patchState({
    lastMemoryLine: {
      noteId: input.noteId,
      noteText: input.noteText,
      entryId: input.entryId,
    },
    lastMemoryLineAt: nowIso(),
  });
}

export function recordThenVsNowSeen(input: {
  noteId: string;
  pastEntryId?: string;
  entryId?: string;
}): void {
  patchState({
    lastThenVsNow: {
      noteId: input.noteId,
      pastEntryId: input.pastEntryId,
      entryId: input.entryId,
    },
    lastThenVsNowAt: nowIso(),
  });
}

export function clearEmotionalContinuity(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(STORAGE_KEY);
}
