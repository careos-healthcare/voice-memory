export type AccountSyncState =
  | "signed_out"
  | "signed_in"
  | "syncing"
  | "sync_error";

export interface AccountUser {
  id: string;
  email: string;
}

export interface AccountSession {
  user: AccountUser;
  signedInAt: string;
}

export interface AccountStatus {
  state: AccountSyncState;
  session: AccountSession | null;
  lastBackupAt: string | null;
  lastSyncError: string | null;
  syncEnabled: boolean;
}
