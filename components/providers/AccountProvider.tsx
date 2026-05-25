"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  fetchAccountSession,
  readAccountStatus,
  sendEmailLoginCode,
  signOutAccount,
  verifyEmailLoginCode,
} from "@/lib/sync/account-client";
import {
  applyEncryptedRestoreFromPreview,
  previewRestoreFromEncryptedBackup,
  restoreArchiveFromEncryptedBackup,
  syncArchiveIfSignedIn,
} from "@/lib/sync/client";
import { SYNC_STATUS_EVENT } from "@/lib/sync/status-storage";
import { syncWarn } from "@/lib/sync/sync-log";
import type { AccountSession, AccountStatus } from "@/types/account";
import type { RestorePreview } from "@/types/sync-health";

interface AccountContextValue {
  status: AccountStatus;
  refresh: () => Promise<void>;
  sendCode: (email: string) => Promise<{ devCode?: string }>;
  verifyCode: (email: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
  syncNow: () => Promise<boolean>;
  previewRestore: () => Promise<RestorePreview>;
  applyRestore: (preview: RestorePreview) => Promise<void>;
  restoreNow: () => Promise<RestorePreview>;
}

const AccountContext = createContext<AccountContextValue | null>(null);

export function AccountProvider({ children }: { children: React.ReactNode }) {
  const hydrated = useClientHydrated();
  const [session, setSession] = useState<AccountSession | null>(null);
  const [tick, setTick] = useState(0);

  const refresh = useCallback(async () => {
    const next = await fetchAccountSession();
    setSession(next);
    setTick((value) => value + 1);
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    const onChange = () => setTick((value) => value + 1);
    window.addEventListener(SYNC_STATUS_EVENT, onChange);
    return () => window.removeEventListener(SYNC_STATUS_EVENT, onChange);
  }, []);

  const status = useMemo(
    () =>
      readAccountStatus(session, {
        includeLocalSyncState: hydrated,
      }),
    [session, tick, hydrated],
  );

  const sendCode = useCallback(async (email: string) => sendEmailLoginCode(email), []);

  const verifyCode = useCallback(
    async (email: string, code: string) => {
      const next = await verifyEmailLoginCode(email, code);
      setSession(next);
      const ok = await syncArchiveIfSignedIn();
      if (!ok && typeof window !== "undefined") {
        syncWarn("Post-sign-in sync did not complete", {
          message: readAccountStatus(next, { includeLocalSyncState: true }).lastSyncError,
        });
      }
      setTick((value) => value + 1);
    },
    [],
  );

  const signOut = useCallback(async () => {
    await signOutAccount();
    setSession(null);
    setTick((value) => value + 1);
  }, []);

  const syncNow = useCallback(async () => {
    const ok = await syncArchiveIfSignedIn();
    setTick((value) => value + 1);
    return ok;
  }, []);

  const previewRestore = useCallback(async () => previewRestoreFromEncryptedBackup(), []);

  const applyRestore = useCallback(async (preview: RestorePreview) => {
    await applyEncryptedRestoreFromPreview(preview);
    setTick((value) => value + 1);
  }, []);

  const restoreNow = useCallback(async () => {
    const preview = await restoreArchiveFromEncryptedBackup();
    setTick((value) => value + 1);
    return preview;
  }, []);

  const value = useMemo(
    () => ({
      status,
      refresh,
      sendCode,
      verifyCode,
      signOut,
      syncNow,
      previewRestore,
      applyRestore,
      restoreNow,
    }),
    [status, refresh, sendCode, verifyCode, signOut, syncNow, previewRestore, applyRestore, restoreNow],
  );

  return <AccountContext.Provider value={value}>{children}</AccountContext.Provider>;
}

export function useAccount(): AccountContextValue {
  const context = useContext(AccountContext);
  if (!context) {
    throw new Error("useAccount must be used within AccountProvider.");
  }
  return context;
}
