export interface LedgerMemoryRow {
  userId: string;
  entryId: string;
  rawText: string;
}

/** Drops every server row for one person. Other people's rows stay. */
export function clearUserLedger(
  rows: readonly LedgerMemoryRow[],
  userId: string,
): LedgerMemoryRow[] {
  const id = userId.trim();
  return rows.filter((row) => row.userId !== id);
}

/** One row per entry. A second write replaces the first. */
export function upsertLedgerRow(
  rows: readonly LedgerMemoryRow[],
  next: LedgerMemoryRow,
): LedgerMemoryRow[] {
  return [
    ...rows.filter(
      (row) => !(row.userId === next.userId && row.entryId === next.entryId),
    ),
    next,
  ];
}

export function deleteLedgerRow(
  rows: readonly LedgerMemoryRow[],
  userId: string,
  entryId: string,
): LedgerMemoryRow[] {
  return rows.filter(
    (row) => !(row.userId === userId && row.entryId === entryId),
  );
}
