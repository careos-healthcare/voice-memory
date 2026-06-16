"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import { EmailCodeAuthModal } from "@/components/auth/EmailCodeAuthModal";
import { useAccount } from "@/components/providers/AccountProvider";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  markAuthPromptShown,
  readAuthTriggerContext,
  shouldOfferArchiveChangedReturnPrompt,
  shouldOfferFirstWorkingBeliefAuth,
  shouldPromptForAuthTrigger,
} from "@/lib/auth/auth-trigger-rules";
import {
  markGuestModeStartedIfNeeded,
  trackAuthPromptShown,
} from "@/lib/auth/guest-first-auth";
import type { AuthTriggerReason } from "@/types/auth-trigger";

interface AuthPromptContextValue {
  requestAuth: (reason: AuthTriggerReason, onSuccess?: () => void) => boolean;
}

const AuthPromptContext = createContext<AuthPromptContextValue | null>(null);

function AuthTriggerObserver({
  requestAuth,
}: {
  requestAuth: AuthPromptContextValue["requestAuth"];
}) {
  const hydrated = useClientHydrated();
  const { status } = useAccount();
  const offeredRef = useRef({ belief: false, archiveReturn: false });

  useEffect(() => {
    if (!hydrated || status.session) return;

    const ctx = readAuthTriggerContext(false);

    if (!offeredRef.current.belief && shouldOfferFirstWorkingBeliefAuth(ctx)) {
      offeredRef.current.belief = true;
      markAuthPromptShown("protect_archive");
      requestAuth("protect_archive");
      return;
    }

    if (!offeredRef.current.archiveReturn && shouldOfferArchiveChangedReturnPrompt(ctx)) {
      offeredRef.current.archiveReturn = true;
      markAuthPromptShown("archive_changed_return");
      requestAuth("archive_changed_return");
    }
  }, [hydrated, status.session, requestAuth]);

  return null;
}

export function AuthPromptProvider({ children }: { children: React.ReactNode }) {
  const hydrated = useClientHydrated();
  const { status } = useAccount();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState<AuthTriggerReason>("protect_archive");
  const onSuccessRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!hydrated) return;
    markGuestModeStartedIfNeeded(Boolean(status.session));
  }, [hydrated, status.session]);

  const requestAuth = useCallback(
    (nextReason: AuthTriggerReason, onSuccess?: () => void): boolean => {
      if (status.session) {
        onSuccess?.();
        return true;
      }

      const ctx = readAuthTriggerContext(false);
      if (!shouldPromptForAuthTrigger(nextReason, ctx)) {
        return false;
      }

      setReason(nextReason);
      onSuccessRef.current = onSuccess ?? null;
      trackAuthPromptShown(nextReason);
      setOpen(true);
      return false;
    },
    [status.session],
  );

  const handleClose = useCallback(() => {
    setOpen(false);
    onSuccessRef.current = null;
  }, []);

  const handleSuccess = useCallback(() => {
    const cb = onSuccessRef.current;
    onSuccessRef.current = null;
    cb?.();
  }, []);

  const value = useMemo(() => ({ requestAuth }), [requestAuth]);

  return (
    <AuthPromptContext.Provider value={value}>
      {children}
      <AuthTriggerObserver requestAuth={requestAuth} />
      <EmailCodeAuthModal
        open={open}
        reason={reason}
        onClose={handleClose}
        onSuccess={handleSuccess}
      />
    </AuthPromptContext.Provider>
  );
}

export function useAuthPrompt(): AuthPromptContextValue {
  const ctx = useContext(AuthPromptContext);
  if (!ctx) {
    throw new Error("useAuthPrompt must be used within AuthPromptProvider.");
  }
  return ctx;
}
