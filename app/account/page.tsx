"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Cloud, LogOut, RefreshCw, Shield } from "lucide-react";

import { PrivacyTrustPanel } from "@/components/trust/PrivacyTrustPanel";
import { ArchiveProtectionLine } from "@/components/monetization/ArchiveProtectionLine";
import { useAccount } from "@/components/providers/AccountProvider";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import {
  isDebugEventSyncAllowed,
  setDebugEventSyncAllowed,
} from "@/lib/sync/archive-bundle";
import { buildEncryptedAudioBackupPlan } from "@/lib/sync/audio-backup";
import {
  buildAccountOwnershipLines,
  buildArchiveOwnershipReport,
} from "@/lib/archive/archive-ownership";
import { buildAccountContinuityStatus } from "@/lib/sync/cross-device-continuity";
import type { AccountContinuityStatus } from "@/lib/sync/cross-device-continuity";
import { AccountAuthError } from "@/lib/sync/account-client";
import {
  accountStatusLabel,
  formatLastBackupLine,
} from "@/lib/sync/account-status-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { ENCRYPTED_SYNC_COPY, SYNC_FAILURE_COPY } from "@/lib/sync/copy";
import { ACCOUNT_BACKUP, PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { DELETE_ACCOUNT_PLACEHOLDER, PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";
import { maybeTrackPostPremiumBehavior } from "@/lib/monetization/monetization-observation";
import { getAllEntries } from "@/lib/storage";
import type { ArchiveOwnershipReport } from "@/types/archive-ownership";

function statusLabel(state: string): string {
  if (
    state === "signed_in" ||
    state === "signed_out" ||
    state === "syncing" ||
    state === "sync_error"
  ) {
    return accountStatusLabel(state);
  }
  return accountStatusLabel("signed_out");
}

type SendCodeUiState =
  | "idle"
  | "sending"
  | "sent"
  | "delivery_unavailable"
  | "sender_rejected"
  | "storage_error";

function sendCodeStatusLine(state: SendCodeUiState): string | null {
  switch (state) {
    case "sending":
      return "Sending…";
    case "sent":
      return "Code sent. Check your email.";
    case "delivery_unavailable":
      return "Email delivery is temporarily unavailable.";
    case "sender_rejected":
      return "Auth email provider rejected the sender address.";
    case "storage_error":
      return "Auth storage is not configured.";
    default:
      return null;
  }
}

function sendCodeStateFromAuthCode(code: string | undefined): SendCodeUiState {
  if (code === "AUTH_STORAGE_NOT_CONFIGURED" || code === "storage_not_configured") {
    return "storage_error";
  }
  if (
    code === "AUTH_INVALID_EMAIL_FROM" ||
    code === "AUTH_RESEND_REJECTED" ||
    code === "email_delivery_failed"
  ) {
    return "sender_rejected";
  }
  return "delivery_unavailable";
}

export default function AccountPage() {
  const hydrated = useClientHydrated();
  const { status, sendCode, verifyCode, signOut, syncNow, previewRestore, applyRestore } =
    useAccount();
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [devCode, setDevCode] = useState<string | null>(null);
  const [sendCodeState, setSendCodeState] = useState<SendCodeUiState>("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [allowDebugEvents, setAllowDebugEvents] = useState(false);
  const [audioPlanCount, setAudioPlanCount] = useState(0);
  const [ownership, setOwnership] = useState<ArchiveOwnershipReport | null>(null);
  const [continuity, setContinuity] = useState<AccountContinuityStatus>({
    archiveContinuesLine: null,
    leftOffLine: null,
    lastBackedUpLine: null,
  });

  useEffect(() => {
    if (!hydrated) return;
    setContinuity(
      buildAccountContinuityStatus({
        signedIn: Boolean(status.session),
        lastBackupAt: status.lastBackupAt,
      }),
    );
  }, [hydrated, status.session, status.lastBackupAt]);

  useEffect(() => {
    setAllowDebugEvents(isDebugEventSyncAllowed());
    setAudioPlanCount(buildEncryptedAudioBackupPlan().items.length);
    void buildArchiveOwnershipReport(getAllEntries()).then(setOwnership);
  }, []);

  const ownershipLines =
    ownership && status.session
      ? buildAccountOwnershipLines(ownership, true)
      : [];

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 4000);
  };

  const handleSendCode = async () => {
    setBusy(true);
    setSendCodeState("sending");
    try {
      const result = await sendCode(email);
      setDevCode(result.devCode ?? null);
      setSendCodeState("sent");
      showMessage("Code sent. Check your email.");
    } catch (error) {
      const authCode = error instanceof AccountAuthError ? error.code : undefined;
      const uiState = sendCodeStateFromAuthCode(authCode);
      setSendCodeState(uiState);
      showMessage(
        error instanceof AccountAuthError
          ? error.message
          : error instanceof Error
            ? error.message
            : "Email delivery is temporarily unavailable.",
      );
    } finally {
      setBusy(false);
    }
  };

  const handleVerify = async () => {
    setBusy(true);
    try {
      await verifyCode(email, code);
      setDevCode(null);
      showMessage("Signed in. Encrypted backup started.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Sign-in failed.");
    } finally {
      setBusy(false);
    }
  };

  const handleSync = async () => {
    setBusy(true);
    try {
      const ok = await syncNow();
      showMessage(
        ok ? "Encrypted backup saved." : "Backup paused. Nothing was deleted.",
      );
      if (ok) {
        maybeTrackPostPremiumBehavior("backup");
        void import("@/lib/retention/return-triggers").then((mod) => {
          mod.registerBackupReturnTrigger();
        });
      }
    } finally {
      setBusy(false);
    }
  };

  const handleRestore = async () => {
    setBusy(true);
    try {
      const preview = await previewRestore();
      const summary = preview.summaryLines.join("\n");
      if (
        !window.confirm(
          `${ENCRYPTED_SYNC_COPY.restoreWarning}\n\n${summary}\n\nContinue?`,
        )
      ) {
        return;
      }
      await applyRestore(preview);
      showMessage("Archive restored from encrypted backup.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Restore failed.");
    } finally {
      setBusy(false);
    }
  };

  const handleSignOut = async () => {
    setBusy(true);
    try {
      await signOut();
      showMessage("Signed out.");
    } finally {
      setBusy(false);
    }
  };

  const handleDebugToggle = (checked: boolean) => {
    setAllowDebugEvents(checked);
    setDebugEventSyncAllowed(checked);
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <MotionPageTitle title="Account" />

        <div className="mt-16 space-y-8">
          <p className="text-sm leading-relaxed text-zinc-400">{PRIVATE_BY_DEFAULT_LINE}</p>
          <p className="text-sm leading-relaxed text-zinc-500">{PRODUCT_WEDGE_LINE}</p>
          <ArchiveProtectionLine surface="account" />

          <Card className="border-white/[0.06] bg-zinc-900/40">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base font-normal text-zinc-200">
                <Shield className="h-4 w-4 text-violet-300/80" />
                Privacy & encrypted backup
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <PrivacyTrustPanel compact />
              <div className="space-y-2 border-t border-white/5 pt-4 text-sm leading-[1.75] text-zinc-500">
                <p>{ENCRYPTED_SYNC_COPY.encryptedBeforeLeave}</p>
                <p>{ENCRYPTED_SYNC_COPY.archiveNotServer}</p>
              </div>
            </CardContent>
          </Card>

          <Card className="border-white/[0.06] bg-zinc-900/40">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base font-normal text-zinc-200">
                <Cloud className="h-4 w-4 text-violet-300/80" />
                Account & sync
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 text-sm text-zinc-400">
              <p>
                Backup status:{" "}
                <span className="text-zinc-300">{statusLabel(status.state)}</span>
              </p>
              {status.session ? (
                <p className="text-zinc-500">{status.session.user.email}</p>
              ) : null}
              <p>{formatLastBackupLine(status.lastBackupAt, hydrated)}</p>
              {status.lastSyncError ? (
                <div className="space-y-1 text-sm leading-relaxed">
                  <p className="text-red-300/90">{status.lastSyncError}</p>
                  <p className="text-zinc-500">{SYNC_FAILURE_COPY.localArchiveSafe}</p>
                  <p className="text-zinc-500">{SYNC_FAILURE_COPY.backupPaused}</p>
                </div>
              ) : null}
              {hydrated && status.session && audioPlanCount > 0 ? (
                <p className="text-zinc-500">
                  Encrypted audio backup: {audioPlanCount} recording
                  {audioPlanCount === 1 ? "" : "s"} queued with the same client-side encryption.
                </p>
              ) : null}

              {hydrated && status.session ? (
                <div className="space-y-2 border-t border-white/5 pt-4 text-sm leading-relaxed text-zinc-500">
                  {continuity.archiveContinuesLine ? (
                    <p>{continuity.archiveContinuesLine}</p>
                  ) : null}
                  {continuity.leftOffLine ? <p>{continuity.leftOffLine}</p> : null}
                </div>
              ) : null}

              {ownershipLines.length > 0 ? (
                <div className="space-y-2 border-t border-white/5 pt-4 text-sm leading-relaxed text-zinc-500">
                  {ownershipLines.map((line) => (
                    <p key={line}>{line}</p>
                  ))}
                </div>
              ) : null}

              {status.session ? (
                <div className="flex flex-wrap gap-3 pt-2">
                  <Button disabled={busy || status.state === "syncing"} onClick={() => void handleSync()}>
                    <RefreshCw className="h-4 w-4" />
                    Back up now
                  </Button>
                  <Button variant="secondary" disabled={busy} onClick={() => void handleRestore()}>
                    Restore backup
                  </Button>
                  <Button variant="ghost" disabled={busy} onClick={() => void handleSignOut()}>
                    <LogOut className="h-4 w-4" />
                    Sign out
                  </Button>
                </div>
              ) : (
                <div className="space-y-4 border-t border-white/5 pt-4">
                  <p className="text-zinc-500">{ACCOUNT_BACKUP.signInPrompt}</p>
                  <input
                    type="email"
                    value={email}
                    onChange={(event) => {
                      setEmail(event.target.value);
                      if (sendCodeState !== "idle") setSendCodeState("idle");
                    }}
                    placeholder="you@example.com"
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  />
                  <Button disabled={busy || !email.trim()} onClick={() => void handleSendCode()}>
                    {sendCodeState === "sending" ? "Sending…" : "Send code"}
                  </Button>
                  {sendCodeStatusLine(sendCodeState) ? (
                    <p
                      className={
                        sendCodeState === "storage_error" ||
                        sendCodeState === "delivery_unavailable" ||
                        sendCodeState === "sender_rejected"
                          ? "text-sm text-red-300/90"
                          : "text-sm text-zinc-400"
                      }
                    >
                      {sendCodeStatusLine(sendCodeState)}
                    </p>
                  ) : null}
                  {devCode ? (
                    <p className="text-xs text-zinc-500">Development code: {devCode}</p>
                  ) : null}
                  <input
                    type="text"
                    inputMode="numeric"
                    value={code}
                    onChange={(event) => setCode(event.target.value)}
                    placeholder="6-digit code"
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  />
                  <Button disabled={busy || !email.trim() || !code.trim()} onClick={() => void handleVerify()}>
                    Sign in
                  </Button>
                </div>
              )}

              <label className="flex items-start gap-3 border-t border-white/5 pt-4 text-sm leading-[1.75] text-zinc-500">
                <input
                  type="checkbox"
                  checked={allowDebugEvents}
                  onChange={(event) => handleDebugToggle(event.target.checked)}
                  className="mt-1"
                />
                <span>Include retention and debug events in encrypted backup (off by default).</span>
              </label>
            </CardContent>
          </Card>

          <section className="rounded-2xl border border-white/[0.06] bg-zinc-900/40 p-5">
            <h2 className="text-base font-normal text-zinc-200">Delete account</h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-500">{DELETE_ACCOUNT_PLACEHOLDER}</p>
            <Link
              href="/settings"
              className="mt-3 inline-block text-sm text-violet-300 hover:text-violet-200"
            >
              Delete all local data →
            </Link>
          </section>

          {message ? <p className="text-sm text-zinc-400">{message}</p> : null}

          <p className="text-sm text-zinc-600">
            <Link href="/settings" className="underline underline-offset-4 hover:text-zinc-400">
              Settings
            </Link>
            {" · "}
            <Link href="/privacy" className="underline underline-offset-4 hover:text-zinc-400">
              Privacy
            </Link>
          </p>
        </div>

        <SiteFooter className="mt-16" />
      </div>
    </div>
  );
}
