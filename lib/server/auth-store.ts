import "server-only";

import { createUserId, hashVerificationCode } from "@/lib/server/auth-crypto";
import {
  readAuthStore,
  writeAuthStore,
  type StoredUser,
} from "@/lib/server/auth-storage";

const CODE_TTL_MS = 1000 * 60 * 10;

export type { StoredUser } from "@/lib/server/auth-storage";
export { AuthStorageNotConfiguredError, getAuthStorageMode } from "@/lib/server/auth-storage";

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function issueEmailLoginCode(email: string): { userId: string; code: string } {
  const normalized = normalizeEmail(email);
  if (!normalized.includes("@")) {
    throw new Error("Enter a valid email address.");
  }

  const store = readAuthStore();
  let user = store.usersByEmail[normalized];
  if (!user) {
    user = {
      id: createUserId(),
      email: normalized,
      createdAt: new Date().toISOString(),
    };
    store.usersByEmail[normalized] = user;
  }

  const code = String(Math.floor(100000 + Math.random() * 900000));
  store.pendingCodes = store.pendingCodes.filter((row) => row.email !== normalized);
  store.pendingCodes.push({
    email: normalized,
    codeHash: hashVerificationCode(code),
    expiresAt: Date.now() + CODE_TTL_MS,
  });
  writeAuthStore(store);

  return { userId: user.id, code };
}

export function verifyEmailLoginCode(email: string, code: string): StoredUser | null {
  const normalized = normalizeEmail(email);
  const store = readAuthStore();
  const pending = store.pendingCodes.find((row) => row.email === normalized);
  if (!pending || pending.expiresAt < Date.now()) return null;

  if (pending.codeHash !== hashVerificationCode(code.trim())) return null;

  const user = store.usersByEmail[normalized];
  if (!user) return null;

  store.pendingCodes = store.pendingCodes.filter((row) => row.email !== normalized);
  writeAuthStore(store);
  return user;
}

export function getUserById(userId: string): StoredUser | null {
  const store = readAuthStore();
  return Object.values(store.usersByEmail).find((user) => user.id === userId) ?? null;
}
