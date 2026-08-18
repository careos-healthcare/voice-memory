import {
  ACCOUNT_BACKUP,
  ACCOUNT_STATUS_LABELS,
} from "@/lib/product-copy";
import { formatEntryDate } from "@/lib/utils";
import type { AccountSyncState } from "@/types/account";

export function accountStatusLabel(state: AccountSyncState): string {
  return ACCOUNT_STATUS_LABELS[state];
}

export function formatLastBackupLine(lastBackupAt: string | null, hydrated: boolean): string {
  if (!hydrated) return "—";
  if (!lastBackupAt) return ACCOUNT_BACKUP.notYetBackedUp;
  return ACCOUNT_BACKUP.lastBackedUp(formatEntryDate(lastBackupAt));
}
