import {
  dispatchSyncStatusChange,
  readLastBackupAt,
  readLastSyncError,
} from "@/lib/sync/status-storage";
import { readResponseJson } from "@/lib/sync/parse-response";
import type { AccountSession, AccountStatus, AccountSyncState } from "@/types/account";

let syncInFlight = false;

export function readAccountStatus(
  session: AccountSession | null,
  options: { includeLocalSyncState?: boolean } = {},
): AccountStatus {
  const includeLocal = options.includeLocalSyncState !== false;
  let state: AccountSyncState = "signed_out";
  if (session) {
    const syncError = includeLocal ? readLastSyncError() : null;
    state = syncInFlight ? "syncing" : syncError ? "sync_error" : "signed_in";
  }

  return {
    state,
    session,
    lastBackupAt: includeLocal ? readLastBackupAt() : null,
    lastSyncError: includeLocal ? readLastSyncError() : null,
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
  const data = await readResponseJson<{ ok?: boolean; session: AccountSession | null }>(
    response,
    { session: null },
    { routeLabel: "auth/session", requireOk: false },
  );
  return data.session ?? null;
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
  const data = await readResponseJson<{
    ok?: boolean;
    error?: string;
    devCode?: string;
    code?: string;
  }>(response, {}, { routeLabel: "auth/send-code", requireOk: false });
  if (!response.ok) {
    throw new AccountAuthError(
      data?.error ?? "Could not send code. Try again.",
      data?.code,
    );
  }
  return { devCode: data?.devCode };
}

export async function verifyEmailLoginCode(email: string, code: string): Promise<AccountSession> {
  const response = await fetch("/api/auth/verify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, code }),
  });
  const data = await readResponseJson<{ ok?: boolean; error?: string; session?: AccountSession }>(
    response,
    {},
    { routeLabel: "auth/verify", requireOk: false },
  );
  if (!response.ok || !data?.session) {
    throw new Error(data?.error ?? "Invalid sign-in code.");
  }
  return data.session;
}

export async function signOutAccount(): Promise<void> {
  await fetch("/api/auth/signout", { method: "POST" });
}
