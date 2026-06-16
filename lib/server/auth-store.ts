import "server-only";

import {
  CODE_TTL_MS,
  evaluateCodeAttempt,
  sendAllowed,
  AuthRateLimitError,
} from "@/lib/auth/auth-code-policy";
import {
  createVerificationCode,
  hashVerificationCode,
  userIdFromEmail,
} from "@/lib/server/auth-crypto";
import {
  issueAuthCodePostgres,
  getUserByIdPostgres,
  verifyAuthCodePostgres,
} from "@/lib/server/auth-store-postgres";
import {
  readAuthStore,
  writeAuthStore,
  type StoredUser,
} from "@/lib/server/auth-storage";
import { shouldUsePostgresStorage } from "@/lib/server/db";

export type { StoredUser } from "@/lib/server/auth-storage";
export { AuthStorageNotConfiguredError, getAuthStorageMode } from "@/lib/server/auth-storage";
export { AuthRateLimitError } from "@/lib/auth/auth-code-policy";

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function issueEmailLoginCodeLocal(email: string): { userId: string; code: string } {
  const normalized = normalizeEmail(email);
  if (!normalized.includes("@")) {
    throw new Error("Enter a valid email address.");
  }

  const store = readAuthStore();
  const now = Date.now();

  // Resend cooldown — one live code per email, no rapid re-issue.
  const existing = store.pendingCodes.find((row) => row.email === normalized);
  const gate = sendAllowed(existing?.issuedAt ?? null, now);
  if (!gate.allowed) {
    throw new AuthRateLimitError(gate.retryAfterMs);
  }

  let user = store.usersByEmail[normalized];
  if (!user) {
    user = {
      id: userIdFromEmail(normalized),
      email: normalized,
      createdAt: new Date().toISOString(),
    };
    store.usersByEmail[normalized] = user;
  }

  const code = createVerificationCode();
  store.pendingCodes = store.pendingCodes.filter((row) => row.email !== normalized);
  store.pendingCodes.push({
    email: normalized,
    codeHash: hashVerificationCode(code),
    expiresAt: now + CODE_TTL_MS,
    attempts: 0,
    issuedAt: now,
  });
  writeAuthStore(store);

  return { userId: user.id, code };
}

function verifyEmailLoginCodeLocal(email: string, code: string): StoredUser | null {
  const normalized = normalizeEmail(email);
  const store = readAuthStore();
  const pending = store.pendingCodes.find((row) => row.email === normalized);

  const decision = evaluateCodeAttempt({
    pending: pending
      ? { expiresAtMs: pending.expiresAt, attempts: pending.attempts ?? 0 }
      : null,
    hashMatches:
      Boolean(pending) && pending!.codeHash === hashVerificationCode(code.trim()),
    nowMs: Date.now(),
  });

  if (decision.outcome === "mismatch" && !decision.invalidate) {
    pending!.attempts = decision.nextAttempts;
    writeAuthStore(store);
    return null;
  }

  if (decision.invalidate) {
    store.pendingCodes = store.pendingCodes.filter((row) => row.email !== normalized);
    writeAuthStore(store);
  }

  if (decision.outcome !== "match") return null;

  const user = store.usersByEmail[normalized];
  if (!user) return null;
  return user;
}

function getUserByIdLocal(userId: string): StoredUser | null {
  const store = readAuthStore();
  return Object.values(store.usersByEmail).find((user) => user.id === userId) ?? null;
}

export async function issueEmailLoginCode(
  email: string,
): Promise<{ userId: string; code: string }> {
  const normalized = normalizeEmail(email);
  if (!normalized.includes("@")) {
    throw new Error("Enter a valid email address.");
  }

  if (shouldUsePostgresStorage()) {
    const code = createVerificationCode();
    return issueAuthCodePostgres(normalized, code);
  }

  return issueEmailLoginCodeLocal(normalized);
}

export async function verifyEmailLoginCode(
  email: string,
  code: string,
): Promise<StoredUser | null> {
  if (shouldUsePostgresStorage()) {
    return verifyAuthCodePostgres(email, code);
  }

  return verifyEmailLoginCodeLocal(email, code);
}

export async function getUserById(userId: string): Promise<StoredUser | null> {
  if (shouldUsePostgresStorage()) {
    return getUserByIdPostgres(userId);
  }

  return getUserByIdLocal(userId);
}
