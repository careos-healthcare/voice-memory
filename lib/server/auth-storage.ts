import "server-only";

import path from "node:path";

import { shouldUsePostgresStorage } from "@/lib/server/db";
import { ensureDataDir, readJsonFile, writeJsonFile } from "@/lib/server/data-path";

export const AUTH_STORAGE_NOT_CONFIGURED = "Auth storage is not configured.";

export type AuthStorageMode = "memory" | "filesystem" | "database" | "unconfigured";

export interface StoredUser {
  id: string;
  email: string;
  createdAt: string;
}

export interface PendingCode {
  email: string;
  codeHash: string;
  expiresAt: number;
}

export interface AuthStoreShape {
  usersByEmail: Record<string, StoredUser>;
  pendingCodes: PendingCode[];
}

export class AuthStorageNotConfiguredError extends Error {
  constructor(message = AUTH_STORAGE_NOT_CONFIGURED) {
    super(message);
    this.name = "AuthStorageNotConfiguredError";
  }
}

interface AuthStorageBackend {
  mode: AuthStorageMode;
  read(): AuthStoreShape;
  write(store: AuthStoreShape): void;
}

const EMPTY_STORE: AuthStoreShape = {
  usersByEmail: {},
  pendingCodes: [],
};

const globalForAuth = globalThis as typeof globalThis & {
  __voicememoryAuthStore?: AuthStoreShape;
};

function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}

function pruneExpiredCodes(store: AuthStoreShape): AuthStoreShape {
  const now = Date.now();
  return {
    ...store,
    pendingCodes: store.pendingCodes.filter((row) => row.expiresAt > now),
  };
}

function memoryBackend(): AuthStorageBackend {
  return {
    mode: "memory",
    read() {
      if (!globalForAuth.__voicememoryAuthStore) {
        globalForAuth.__voicememoryAuthStore = { ...EMPTY_STORE };
      }
      return pruneExpiredCodes(globalForAuth.__voicememoryAuthStore);
    },
    write(store) {
      globalForAuth.__voicememoryAuthStore = pruneExpiredCodes(store);
    },
  };
}

function filesystemBackend(): AuthStorageBackend {
  const storePath = path.join(ensureDataDir("auth"), "store.json");
  return {
    mode: "filesystem",
    read() {
      return pruneExpiredCodes(readJsonFile<AuthStoreShape>(storePath, { ...EMPTY_STORE }));
    },
    write(store) {
      writeJsonFile(storePath, pruneExpiredCodes(store));
    },
  };
}

function resolveBackend(): AuthStorageBackend {
  if (shouldUsePostgresStorage()) {
    throw new Error("Local auth backend must not be used when DATABASE_URL is set.");
  }

  if (isProduction()) {
    return memoryBackend();
  }

  return filesystemBackend();
}

let cachedBackend: AuthStorageBackend | null = null;

function backend(): AuthStorageBackend {
  if (shouldUsePostgresStorage()) {
    throw new Error("Local auth backend must not be used when DATABASE_URL is set.");
  }

  if (!cachedBackend) {
    cachedBackend = resolveBackend();
  }
  return cachedBackend;
}

export function getAuthStorageMode(): AuthStorageMode {
  if (shouldUsePostgresStorage()) {
    return "database";
  }

  try {
    return backend().mode;
  } catch (error) {
    if (error instanceof AuthStorageNotConfiguredError) {
      return "unconfigured";
    }
    throw error;
  }
}

export function readAuthStore(): AuthStoreShape {
  return backend().read();
}

export function writeAuthStore(store: AuthStoreShape): void {
  backend().write(store);
}

export function authStorageUsesFilesystemInProduction(): boolean {
  return isProduction() && getAuthStorageMode() === "filesystem";
}
