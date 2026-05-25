import {
  dispatchSyncStatusChange,
  readLastBackupAt,
  readLastSyncError,
} from "@/lib/sync/status-storage";
import type { AccountSession, AccountStatus, AccountSyncState } from "@/types/account";

let syncInFlight = false;

export function readAccountStatus(session: AccountSession | null): AccountStatus {
  let state: AccountSyncState = "signed_out";
  if (session) {
    state = syncInFlight ? "syncing" : readLastSyncError() ? "sync_error" : "signed_in";
  }

  return {
    state,
    session,
    lastBackupAt: readLastBackupAt(),
    lastSyncError: readLastSyncError(),
    syncEnabled: Boolean(session),
  };
}

export function markSyncStarted(): void {
  syncInFlight = true;
  dispatchSyncStatusChange();
}

export function markSyncFinished(): void {
  syncInFlight = false;
  dispatchSyncStatusChange();
}

export async function fetchAccountSession(): Promise<AccountSession | null> {
  const response = await fetch("/api/auth/session", { cache: "no-store" });
  if (!response.ok) return null;
  const data = (await response.json()) as { session: AccountSession | null };
  return data.session;
}

export class AccountAuthError extends Error {
  code?: string;

  constructor(message: string, code?: string) {
    super(message);
    this.name = "AccountAuthError";
    this.code = code;
  }
}

export async function sendEmailLoginCode(email: string): Promise<{ devCode?: string }> {
  const response = await fetch("/api/auth/send-code", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email }),
  });
  const data = (await response.json()) as {
    error?: string;
    devCode?: string;
    code?: string;
  };
  if (!response.ok) {
    throw new AccountAuthError(
      data.error ?? "Could not send code. Try again.",
      data.code,
    );
  }
  return { devCode: data.devCode };
}

export async function verifyEmailLoginCode(email: string, code: string): Promise<AccountSession> {
  const response = await fetch("/api/auth/verify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, code }),
  });
  const data = (await response.json()) as { error?: string; session?: AccountSession };
  if (!response.ok || !data.session) {
    throw new Error(data.error ?? "Invalid sign-in code.");
  }
  return data.session;
}

export async function signOutAccount(): Promise<void> {
  await fetch("/api/auth/signout", { method: "POST" });
}
