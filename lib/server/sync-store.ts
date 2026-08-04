import "server-only";

import path from "node:path";

import { shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import { ensureDataDir, readJsonFile, writeJsonFile } from "@/lib/server/data-path";
import {
  readEncryptedBlobsPostgres,
  readSyncManifestPostgres,
  upsertEncryptedBlobsPostgres,
} from "@/lib/server/sync-store-postgres";
import type { EncryptedPayload, SyncBlobType, SyncManifest } from "@/types/sync";

export interface StoredSyncBlob {
  id: string;
  type: SyncBlobType;
  encrypted: EncryptedPayload;
  updatedAt: string;
  byteLength: number;
  deviceId?: string;
  vectorClock?: Record<string, number>;
  keyEpoch?: number;
}

interface UserSyncStore {
  userId: string;
  version: number;
  updatedAt: string;
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
    blobs: store.blobs.map((blob) => ({
      id: blob.id,
      type: blob.type,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
    })),
  };
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

export function deleteLocalSyncStore(userId: string): number {
  const existing = globalForSync.__voicememorySyncStores?.[userId];
  if (globalForSync.__voicememorySyncStores) {
    delete globalForSync.__voicememorySyncStores[userId];
  }
  return existing ? existing.blobs.length : 0;
}

export function localSyncStoreExists(userId: string): boolean {
  return Boolean(globalForSync.__voicememorySyncStores?.[userId]?.blobs.length);
}
