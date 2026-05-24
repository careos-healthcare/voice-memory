import "server-only";

import path from "node:path";

import { ensureDataDir, readJsonFile, writeJsonFile } from "@/lib/server/data-path";
import type { EncryptedPayload, SyncBlobType, SyncManifest } from "@/types/sync";

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
  blobs: StoredSyncBlob[];
}

function userStorePath(userId: string): string {
  return path.join(ensureDataDir("sync", userId), "blobs.json");
}

function readUserStore(userId: string): UserSyncStore {
  return readJsonFile<UserSyncStore>(userStorePath(userId), {
    userId,
    version: 0,
    updatedAt: new Date(0).toISOString(),
    blobs: [],
  });
}

function writeUserStore(store: UserSyncStore): void {
  store.updatedAt = new Date().toISOString();
  store.version += 1;
  writeJsonFile(userStorePath(store.userId), store);
}

/** Persist encrypted blobs only — no plaintext archive fields. */
export function upsertEncryptedBlobs(
  userId: string,
  blobs: StoredSyncBlob[],
): SyncManifest {
  const store = readUserStore(userId);
  const byId = new Map(store.blobs.map((blob) => [blob.id, blob]));

  for (const blob of blobs) {
    byId.set(blob.id, blob);
  }

  store.blobs = [...byId.values()].sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
  );
  writeUserStore(store);

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

export function readSyncManifest(userId: string): SyncManifest {
  const store = readUserStore(userId);
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

export function readEncryptedBlobs(userId: string): StoredSyncBlob[] {
  return readUserStore(userId).blobs;
}
