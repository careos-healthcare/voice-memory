import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

export async function isAccountDeletionPending(userId: string): Promise<boolean> {
  if (!shouldUsePostgresStorage()) return false;
  const result = await dbQuery(
    `SELECT 1 FROM account_deletion_requests WHERE user_id = $1 LIMIT 1`,
    [userId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function assertAccountDeletionNotPending(userId: string): Promise<void> {
  if (await isAccountDeletionPending(userId)) {
    throw new Error("ACCOUNT_DELETION_PENDING");
  }
}
