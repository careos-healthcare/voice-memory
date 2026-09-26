import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

import { ledgerLabelPattern } from "./entity_request";

/// Deletes ledger rows whose saved text mentions one forgotten label.
export async function deleteLedgerLabel(
  userId: string,
  label: string,
): Promise<number> {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to delete the fact ledger.");
  }

  const normalizedUserId = userId.trim();
  const pattern = ledgerLabelPattern(label);
  if (!normalizedUserId || !pattern) {
    throw new Error("A label is required to delete ledger text.");
  }

  const result = await dbQuery(
    `DELETE FROM fact_ledger
     WHERE user_id = $1
       AND raw_text ILIKE $2 ESCAPE '\\'`,
    [normalizedUserId, pattern],
  );
  return result.rowCount ?? 0;
}
