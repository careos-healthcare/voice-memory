import "server-only";

import fs from "node:fs";
import path from "node:path";

import { hashSessionToken } from "@/lib/server/auth-crypto";
import { revokeSessionPostgres } from "@/lib/server/auth-store-postgres";
import { deleteServerBilling } from "@/lib/server/billing-entitlements";
import { dbQuery, shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import { ensureDataDir } from "@/lib/server/data-path";
import { deleteAllServerJournalEntries } from "@/lib/server/journal-store";
import { deleteResurfacingFeedbackForUser } from "@/lib/server/resurfacing-feedback-store";

export async function deleteUserServerData(userId: string, email: string): Promise<{
  syncBlobsRemoved: number;
  sessionsRemoved: number;
}> {
  let syncBlobsRemoved = 0;
  let sessionsRemoved = 0;

  if (shouldUsePostgresStorage()) {
    const blobs = await dbQuery(
      `DELETE FROM sync_blobs WHERE user_id = $1`,
      [userId],
    );
    syncBlobsRemoved = blobs.rowCount ?? 0;

    const sessions = await dbQuery(
      `DELETE FROM sessions WHERE user_id = $1`,
      [userId],
    );
    sessionsRemoved = sessions.rowCount ?? 0;

    await dbQuery(`DELETE FROM auth_codes WHERE email = $1`, [email.trim().toLowerCase()]);

    await dbQuery(`DELETE FROM api_usage WHERE subject_key = $1`, [`user:${userId}`]);
    await dbQuery(`DELETE FROM api_minute_usage WHERE subject_key = $1`, [`user:${userId}`]);
    await dbQuery(`DELETE FROM resurfacing_events WHERE user_id = $1`, [userId]);
    await deleteResurfacingFeedbackForUser(userId);
    await deleteAllServerJournalEntries(userId);
    await deleteServerBilling(userId);
  }

  if (shouldUseFilesystemStorage()) {
    const syncDir = path.join(ensureDataDir("sync", userId));
    if (fs.existsSync(syncDir)) {
      fs.rmSync(syncDir, { recursive: true, force: true });
      syncBlobsRemoved = 1;
    }
  }

  return { syncBlobsRemoved, sessionsRemoved };
}

export async function revokeAllSessionsForUser(
  userId: string,
  currentToken?: string,
): Promise<void> {
  if (!shouldUsePostgresStorage()) return;

  if (currentToken) {
    await revokeSessionPostgres(currentToken);
  }

  await dbQuery(`DELETE FROM sessions WHERE user_id = $1`, [userId]);
}

export function hashTokenForAudit(token: string): string {
  return hashSessionToken(token).slice(0, 12);
}
