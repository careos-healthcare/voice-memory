import "server-only";

import {
  hashSessionToken,
  hashVerificationCode,
  userIdFromEmail,
} from "@/lib/server/auth-crypto";
import { dbQuery } from "@/lib/server/db";
import type { StoredUser } from "@/lib/server/auth-storage";

const CODE_TTL_MS = 1000 * 60 * 10;
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export async function issueAuthCodePostgres(
  email: string,
  code: string,
): Promise<{ userId: string; code: string }> {
  const normalized = normalizeEmail(email);
  const expiresAt = new Date(Date.now() + CODE_TTL_MS);
  const codeHash = hashVerificationCode(code);

  await dbQuery(
    `INSERT INTO auth_codes (email, code_hash, expires_at)
     VALUES ($1, $2, $3)
     ON CONFLICT (email) DO UPDATE SET
       code_hash = EXCLUDED.code_hash,
       expires_at = EXCLUDED.expires_at,
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
  }>(
    `SELECT email, code_hash, created_at
     FROM auth_codes
     WHERE email = $1 AND expires_at > $2`,
    [normalized, now],
  );

  const row = result.rows[0];
  if (!row || row.code_hash !== codeHash) return null;

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
