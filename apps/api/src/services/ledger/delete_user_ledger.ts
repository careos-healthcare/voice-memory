import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

/// Removes one person's server-side fact ledger. The account and the copy
/// on their device stay.
export async function deleteUserLedger(userId: string): Promise<number> {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to delete the fact ledger.");
  }

  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required to delete the fact ledger.");
  }

  const result = await dbQuery(
    `DELETE FROM fact_ledger WHERE user_id = $1`,
    [normalizedUserId],
  );
  return result.rowCount ?? 0;
}
