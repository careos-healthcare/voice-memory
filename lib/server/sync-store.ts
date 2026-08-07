import "server-only";

import path from "node:path";

import { shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import { ensureDataDir, readJsonFile, removeDataPath, writeJsonFile } from "@/lib/server/data-path";
import {
  deleteSyncBlobsForUserPostgres,
  readEncryptedBlobsPostgres,
  readSyncChangesSincePostgres,
  readSyncManifestPostgres,
  upsertEncryptedBlobsPostgres,
} from "@/lib/server/sync-store-postgres";
import type { EncryptedPayload, SyncBlobType, SyncChangeRecord, SyncChangesResponse, SyncManifest } from "@/types/sync";

export interface StoredSyncBlob {
  id: string;
  type: SyncBlobType;
  encrypted: EncryptedPayload;
  updatedAt: string;
  byteLength: number;
}

interface UserSyncStore {
  userId: string;
  version: number;
  updatedAt: string;
  changeSequence: number;
  changes: SyncChangeRecord[];
  blobs: StoredSyncBlob[];
}

export type SyncStorageMode = "memory" | "filesystem" | "database";

const globalForSync = globalThis as typeof globalThis & {
  __voicememorySyncStores?: Record<string, UserSyncStore>;
};

function memoryStoreForUser(userId: string): UserSyncStore {
  if (!globalForSync.__voicememorySyncStores) {
    globalForSync.__voicememorySyncStores = {};
  }
  if (!globalForSync.__voicememorySyncStores[userId]) {
    globalForSync.__voicememorySyncStores[userId] = {
      userId,
      version: 0,
      updatedAt: new Date(0).toISOString(),
      changeSequence: 0,
      changes: [],
      blobs: [],
    };
  }
  return globalForSync.__voicememorySyncStores[userId];
}

function userStorePath(userId: string): string {
  return path.join(ensureDataDir("sync", userId), "blobs.json");
}

function readUserStoreFilesystem(userId: string): UserSyncStore {
  return readJsonFile<UserSyncStore>(userStorePath(userId), {
    userId,
    version: 0,
    updatedAt: new Date(0).toISOString(),
    changeSequence: 0,
    changes: [],
    blobs: [],
  });
}

function writeUserStoreFilesystem(store: UserSyncStore): void {
  store.updatedAt = new Date().toISOString();
  store.version += 1;
  writeJsonFile(userStorePath(store.userId), store);
}

function readUserStore(userId: string): UserSyncStore {
  if (shouldUseFilesystemStorage()) {
    return readUserStoreFilesystem(userId);
  }
  return memoryStoreForUser(userId);
}

function writeUserStore(store: UserSyncStore): void {
  if (shouldUseFilesystemStorage()) {
    writeUserStoreFilesystem(store);
    return;
  }
  store.updatedAt = new Date().toISOString();
  store.version += 1;
}

export function getSyncStorageMode(): SyncStorageMode {
  if (shouldUsePostgresStorage()) return "database";
  if (shouldUseFilesystemStorage()) return "filesystem";
  return "memory";
}

export function syncStorageUsesFilesystemInProduction(): boolean {
  return process.env.NODE_ENV === "production" && getSyncStorageMode() === "filesystem";
}

function manifestFromStore(store: UserSyncStore): SyncManifest {
  return {
    userId: store.userId,
    version: store.version,
    updatedAt: store.updatedAt,
    latestSequence: store.changeSequence,
    blobs: store.blobs.map((blob) => ({
      id: blob.id,
      type: blob.type,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
    })),
  };
}

function appendChangeRecords(
  store: UserSyncStore,
  blobs: StoredSyncBlob[],
): void {
  for (const blob of blobs) {
    store.changeSequence += 1;
    store.changes.push({
      sequence: store.changeSequence,
      blobType: blob.type,
      blobId: blob.id,
      changeKind: "upsert",
      updatedAt: blob.updatedAt,
      tombstone: false,
    });
  }
  if (store.changes.length > 2000) {
    store.changes = store.changes.slice(-2000);
  }
}

/** Persist encrypted blobs only — no plaintext archive fields. */
export async function upsertEncryptedBlobs(
  userId: string,
  blobs: StoredSyncBlob[],
): Promise<SyncManifest> {
  if (shouldUsePostgresStorage()) {
    return upsertEncryptedBlobsPostgres(userId, blobs);
  }

  const store = readUserStore(userId);
  const byId = new Map(store.blobs.map((blob) => [blob.id, blob]));

  for (const blob of blobs) {
    byId.set(blob.id, blob);
  }

  appendChangeRecords(store, blobs);
  store.blobs = [...byId.values()].sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
  );
  writeUserStore(store);

  return manifestFromStore(store);
}

export async function readSyncManifest(userId: string): Promise<SyncManifest> {
  if (shouldUsePostgresStorage()) {
    return readSyncManifestPostgres(userId);
  }

  return manifestFromStore(readUserStore(userId));
}

export async function readEncryptedBlobs(userId: string): Promise<StoredSyncBlob[]> {
  if (shouldUsePostgresStorage()) {
    return readEncryptedBlobsPostgres(userId);
  }

  return readUserStore(userId).blobs;
}

/** Incremental pull — changes since [sinceSequence] plus affected blob payloads. */
export async function readSyncChangesSince(
  userId: string,
  sinceSequence: number,
): Promise<SyncChangesResponse> {
  if (shouldUsePostgresStorage()) {
    return readSyncChangesSincePostgres(userId, sinceSequence);
  }

  const store = readUserStore(userId);
  const changes = store.changes.filter((change) => change.sequence > sinceSequence);
  const blobIds = new Set(changes.map((change) => change.blobId));
  const blobs = store.blobs
    .filter((blob) => blobIds.has(blob.id))
    .map((blob) => ({
      id: blob.id,
      type: blob.type,
      encrypted: blob.encrypted,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
    }));

  return {
    latestSequence: store.changeSequence,
    changes,
    blobs,
  };
}

/**
 * Deletes every encrypted sync blob for a user, across whichever mode is
 * currently active. Idempotent — a second call finds nothing and returns 0.
 */
export async function deleteSyncDataForUser(
  userId: string,
): Promise<{ mode: SyncStorageMode; count: number }> {
  if (shouldUsePostgresStorage()) {
    const count = await deleteSyncBlobsForUserPostgres(userId);
    return { mode: "database", count };
  }

  if (shouldUseFilesystemStorage()) {
    const removed = removeDataPath("sync", userId);
    return { mode: "filesystem", count: removed ? 1 : 0 };
  }

  const existed = Boolean(globalForSync.__voicememorySyncStores?.[userId]);
  if (globalForSync.__voicememorySyncStores) {
    delete globalForSync.__voicememorySyncStores[userId];
  }
  return { mode: "memory", count: existed ? 1 : 0 };
}
