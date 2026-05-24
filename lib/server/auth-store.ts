import "server-only";

import path from "node:path";

import { ensureDataDir, readJsonFile, writeJsonFile } from "@/lib/server/data-path";
import { createUserId, hashVerificationCode } from "@/lib/server/auth-crypto";

interface StoredUser {
  id: string;
  email: string;
  createdAt: string;
}

interface PendingCode {
  email: string;
  codeHash: string;
  expiresAt: number;
}

interface AuthStoreShape {
  usersByEmail: Record<string, StoredUser>;
  pendingCodes: PendingCode[];
}

const STORE_PATH = path.join(ensureDataDir("auth"), "store.json");
const CODE_TTL_MS = 1000 * 60 * 10;

function readStore(): AuthStoreShape {
  return readJsonFile<AuthStoreShape>(STORE_PATH, {
    usersByEmail: {},
    pendingCodes: [],
  });
}

function writeStore(store: AuthStoreShape): void {
  const now = Date.now();
  store.pendingCodes = store.pendingCodes.filter((row) => row.expiresAt > now);
  writeJsonFile(STORE_PATH, store);
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function issueEmailLoginCode(email: string): { userId: string; code: string } {
  const normalized = normalizeEmail(email);
  if (!normalized.includes("@")) {
    throw new Error("Enter a valid email address.");
  }

  const store = readStore();
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
  writeStore(store);

  return { userId: user.id, code };
}

export function verifyEmailLoginCode(
  email: string,
  code: string,
): StoredUser | null {
  const normalized = normalizeEmail(email);
  const store = readStore();
  const pending = store.pendingCodes.find((row) => row.email === normalized);
  if (!pending || pending.expiresAt < Date.now()) return null;

  if (pending.codeHash !== hashVerificationCode(code.trim())) return null;

  const user = store.usersByEmail[normalized];
  if (!user) return null;

  store.pendingCodes = store.pendingCodes.filter((row) => row.email !== normalized);
  writeStore(store);
  return user;
}

export function getUserById(userId: string): StoredUser | null {
  const store = readStore();
  return Object.values(store.usersByEmail).find((user) => user.id === userId) ?? null;
}
