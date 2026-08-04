import "server-only";

import {
  CODE_TTL_MS,
  MAX_CODE_ATTEMPTS,
  sendAllowed,
  AuthRateLimitError,
} from "@/lib/auth/auth-code-policy";
import {
  hashSessionToken,
  hashVerificationCode,
  userIdFromEmail,
} from "@/lib/server/auth-crypto";
import { dbQuery } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";
import type { StoredUser } from "@/lib/server/auth-storage";

const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export async function issueAuthCodePostgres(
  email: string,
  code: string,
): Promise<{ userId: string; code: string }> {
  const normalized = normalizeEmail(email);
  await assertAccountDeletionNotPending(userIdFromEmail(normalized));
  const now = Date.now();

  // Resend cooldown — refuse a new code while the last one is fresh.
  const existing = await dbQuery<{ created_at: string }>(
    `SELECT created_at FROM auth_codes WHERE email = $1`,
    [normalized],
  );
  const createdAt = existing.rows[0]?.created_at;
  const gate = sendAllowed(createdAt ? new Date(createdAt).getTime() : null, now);
  if (!gate.allowed) {
    throw new AuthRateLimitError(gate.retryAfterMs);
  }

  const expiresAt = new Date(now + CODE_TTL_MS);
  const codeHash = hashVerificationCode(code);

  await dbQuery(
    `INSERT INTO auth_codes (email, code_hash, expires_at, attempts)
     VALUES ($1, $2, $3, 0)
     ON CONFLICT (email) DO UPDATE SET
       code_hash = EXCLUDED.code_hash,
       expires_at = EXCLUDED.expires_at,
       attempts = 0,
       created_at = now()`,
    [normalized, codeHash, expiresAt.toISOString()],
  );

  return { userId: userIdFromEmail(normalized), code };
}

export async function verifyAuthCodePostgres(
  email: string,
  code: string,
): Promise<StoredUser | null> {
  const normalized = normalizeEmail(email);
  const codeHash = hashVerificationCode(code.trim());
  const now = new Date().toISOString();

  const result = await dbQuery<{
    email: string;
    code_hash: string;
    created_at: string;
    attempts: number;
  }>(
    `SELECT email, code_hash, created_at, attempts
     FROM auth_codes
     WHERE email = $1 AND expires_at > $2`,
    [normalized, now],
  );

  const row = result.rows[0];
  if (!row) return null;

  // Attempt limit — the code dies after too many wrong guesses, even
  // inside its TTL, so a 6-digit code cannot be brute-forced.
  if ((row.attempts ?? 0) >= MAX_CODE_ATTEMPTS) {
    await dbQuery(`DELETE FROM auth_codes WHERE email = $1`, [normalized]);
    return null;
  }

  if (row.code_hash !== codeHash) {
    await dbQuery(
      `UPDATE auth_codes SET attempts = attempts + 1 WHERE email = $1`,
      [normalized],
    );
    return null;
  }

  await dbQuery(`DELETE FROM auth_codes WHERE email = $1`, [normalized]);

  return {
    id: userIdFromEmail(normalized),
    email: normalized,
    createdAt: row.created_at,
  };
}

export async function persistSessionPostgres(
  token: string,
  user: StoredUser,
): Promise<void> {
  await assertAccountDeletionNotPending(user.id);
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);
  await dbQuery(
    `INSERT INTO sessions (token_hash, user_id, email, expires_at)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (token_hash) DO UPDATE SET
       user_id = EXCLUDED.user_id,
       email = EXCLUDED.email,
       expires_at = EXCLUDED.expires_at`,
    [hashSessionToken(token), user.id, user.email, expiresAt.toISOString()],
  );
  await dbQuery(
    `INSERT INTO user_profiles (user_id, focus_area, onboarding_completed)
     VALUES ($1, 'General', false)
     ON CONFLICT (user_id) DO NOTHING`,
    [user.id],
  );
}

export async function revokeSessionPostgres(token: string): Promise<void> {
  await dbQuery(`DELETE FROM sessions WHERE token_hash = $1`, [hashSessionToken(token)]);
}

export async function sessionExistsPostgres(token: string): Promise<boolean> {
  const result = await dbQuery<{ token_hash: string }>(
    `SELECT token_hash
     FROM sessions
     WHERE token_hash = $1 AND expires_at > $2`,
    [hashSessionToken(token), new Date().toISOString()],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function getUserByIdPostgres(userId: string): Promise<StoredUser | null> {
  const result = await dbQuery<{ user_id: string; email: string; created_at: string }>(
    `SELECT user_id, email, created_at
     FROM sessions
     WHERE user_id = $1
     ORDER BY created_at ASC
     LIMIT 1`,
    [userId],
  );

  const row = result.rows[0];
  if (!row) return null;

  return {
    id: row.user_id,
    email: row.email,
    createdAt: row.created_at,
  };
}
