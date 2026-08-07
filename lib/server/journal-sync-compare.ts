import { createHash } from "node:crypto";

import type { JournalEntry } from "@/types/journal";

/**
 * Shared conflict-ordering contract with the mobile client. Mirrors
 * `JournalSyncCompare.compare` in
 * apps/voicememory_mobile/lib/models/journal_entry.dart exactly:
 *   1. Higher `revision` wins.
 *   2. Later `updatedAt` wins.
 *   3. Lexically-greater `changeId` wins as a final, deterministic tie-break.
 *
 * Both sides must agree on this ordering for cross-device sync to converge,
 * so any change here must be mirrored on mobile (and vice versa).
 */
export interface JournalRevisionLike {
  revision: number;
  updatedAt: string;
  changeId: string;
}

/**
 * Returns a positive number if `a` should win over `b`, negative if `b`
 * should win, or 0 only when both are identical on every ordering key
 * (same revision, updatedAt and changeId).
 */
export function compareJournalRevisions(
  a: JournalRevisionLike,
  b: JournalRevisionLike,
): number {
  if (a.revision !== b.revision) return a.revision - b.revision;

  const aTime = Date.parse(a.updatedAt);
  const bTime = Date.parse(b.updatedAt);
  if (aTime !== bTime) return aTime - bTime;

  if (a.changeId === b.changeId) return 0;
  return a.changeId > b.changeId ? 1 : -1;
}

export interface JournalSyncMetadata {
  updatedAt: string;
  revision: number;
  changeId: string;
  schemaVersion: number;
}

/**
 * Deterministic changeId for legacy (pre-migration) entries that never had
 * one — derived only from stable fields so migrating the same entry twice
 * (e.g. re-deriving metadata on every read before it's persisted) always
 * produces the same value. This does not need to match mobile's UUID v5
 * value byte-for-byte (mobile entries always carry their own real changeId
 * once migrated); it only needs to be internally deterministic and stable.
 */
export function computeLegacyChangeId(
  id: string,
  createdAt: string,
  revision: number,
): string {
  return createHash("sha256")
    .update(`archiveme-legacy-journal:${id}:${createdAt}:${revision}`)
    .digest("hex")
    .slice(0, 32);
}

/**
 * Fills in sync-versioning defaults for an entry that may be missing
 * `updatedAt`/`revision`/`changeId`/`schemaVersion` (legacy schema v1
 * clients, or entries written before this feature existed). Never throws;
 * always returns a fully-populated metadata object.
 */
export function deriveJournalSyncMetadata(entry: JournalEntry): JournalSyncMetadata {
  const updatedAt =
    typeof entry.updatedAt === "string" && !Number.isNaN(Date.parse(entry.updatedAt))
      ? entry.updatedAt
      : entry.createdAt;

  const revision =
    typeof entry.revision === "number" &&
    Number.isInteger(entry.revision) &&
    entry.revision >= 1
      ? entry.revision
      : 1;

  const changeId =
    typeof entry.changeId === "string" && entry.changeId.trim().length > 0
      ? entry.changeId
      : computeLegacyChangeId(entry.id, entry.createdAt, revision);

  const schemaVersion =
    typeof entry.schemaVersion === "number" && Number.isInteger(entry.schemaVersion)
      ? entry.schemaVersion
      : 1;

  return { updatedAt, revision, changeId, schemaVersion };
}

/** Applies `deriveJournalSyncMetadata` and returns a fully-versioned copy of the entry. */
export function withDerivedJournalSyncMetadata(entry: JournalEntry): JournalEntry {
  return { ...entry, ...deriveJournalSyncMetadata(entry) };
}
