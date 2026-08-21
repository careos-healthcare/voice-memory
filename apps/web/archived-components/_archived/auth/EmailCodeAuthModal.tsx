"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";

import { useAccount } from "@/components/providers/AccountProvider";
import { Button } from "@/archived-components/_archived/ui/button";
import { AccountAuthError } from "@/lib/sync/account-client";
import { AUTH_TRIGGER_COPY } from "@/lib/auth/auth-trigger-rules";
import { registerDeviceAfterSignIn, trackAuthVerified } from "@/lib/auth/guest-first-auth";
import type { AuthTriggerReason } from "@/types/auth-trigger";

interface EmailCodeAuthModalProps {
  open: boolean;
  reason: AuthTriggerReason;
  onClose: () => void;
  onSuccess?: () => void;
}

export function EmailCodeAuthModal({
  open,
  reason,
  onClose,
  onSuccess,
}: EmailCodeAuthModalProps) {
  const { sendCode, verifyCode } = useAccount();
  const copy = AUTH_TRIGGER_COPY[reason];
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [devCode, setDevCode] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [codeSent, setCodeSent] = useState(false);

  useEffect(() => {
    if (!open) {
      setCode("");
      setDevCode(null);
      setError(null);
      setCodeSent(false);
      setBusy(false);
    }
  }, [open]);

  if (!open) return null;

  const handleSendCode = async () => {
    setBusy(true);
    setError(null);
    try {
      const result = await sendCode(email.trim());
      setDevCode(result.devCode ?? null);
      setCodeSent(true);
    } catch (err) {
      setError(
        err instanceof AccountAuthError
          ? err.message
          : err instanceof Error
            ? err.message
            : "Could not send code.",
      );
    } finally {
      setBusy(false);
    }
  };

  const handleVerify = async () => {
    setBusy(true);
    setError(null);
    try {
      await verifyCode(email.trim(), code.trim());
      await registerDeviceAfterSignIn();
      trackAuthVerified(reason);
      onSuccess?.();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[80] flex items-end justify-center bg-black/70 p-4 sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="email-auth-modal-title"
      data-testid="email-code-auth-modal"
    >
      <div className="w-full max-w-md rounded-2xl border border-white/10 bg-zinc-900 p-5 shadow-xl">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">Email sign-in</p>
            <h2 id="email-code-auth-modal-title" className="mt-1 text-lg font-semibold text-white">
              {copy.title}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1 text-zinc-500 hover:bg-white/5 hover:text-zinc-300"
            aria-label="Close"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <p className="mt-3 text-sm leading-relaxed text-zinc-400">{copy.lead}</p>

        <label className="mt-4 block space-y-1 text-sm">
          <span className="text-zinc-500">Email</span>
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-zinc-950 px-3 py-2 text-zinc-100"
            placeholder="you@example.com"
          />
        </label>

        {codeSent ? (
          <label className="mt-3 block space-y-1 text-sm">
            <span className="text-zinc-500">Code</span>
            <input
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              className="w-full rounded-lg border border-white/10 bg-zinc-950 px-3 py-2 text-zinc-100"
              placeholder="6-digit code"
            />
          </label>
        ) : null}

        {devCode ? (
          <p className="mt-2 text-xs text-amber-400/90">Dev code: {devCode}</p>
        ) : null}

        {error ? <p className="mt-3 text-sm text-amber-300/90">{error}</p> : null}

        <div className="mt-5 flex flex-wrap gap-2">
          {!codeSent ? (
            <Button type="button" disabled={busy || !email.trim()} onClick={() => void handleSendCode()}>
              {busy ? "Sending…" : copy.cta}
            </Button>
          ) : (
            <Button type="button" disabled={busy || !code.trim()} onClick={() => void handleVerify()}>
              {busy ? "Signing in…" : "Continue"}
            </Button>
          )}
          <Button type="button" variant="ghost" disabled={busy} onClick={onClose}>
            Not now
          </Button>
        </div>
      </div>
    </div>
  );
}
