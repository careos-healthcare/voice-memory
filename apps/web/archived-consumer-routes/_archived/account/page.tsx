"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Cloud, LogOut, RefreshCw, Shield } from "lucide-react";

import { SyncStatus } from "@/archived-components/_archived/system/SyncStatus";
import { PrivacyTrustPanel } from "@/components/trust/PrivacyTrustPanel";
import { AccountSecondaryNav } from "@/archived-components/_archived/account/AccountSecondaryNav";
import { ArchiveHistorySummary } from "@/archived-components/_archived/archive/ArchiveHistorySummary";
import { ArchiveMilestones } from "@/archived-components/_archived/archive/ArchiveMilestones";
import { ArchiveAssetCard } from "@/archived-components/_archived/archive/ArchiveAssetCard";
import { ArchiveWorthStatement } from "@/archived-components/_archived/archive/ArchiveWorthStatement";
import { ArchiveProtectionLine } from "@/archived-components/_archived/monetization/ArchiveProtectionLine";
import { useAuthPrompt } from "@/archived-components/_archived/auth/AuthPromptProvider";
import { useAccount } from "@/components/providers/AccountProvider";
import { SiteFooter } from "@/components/SiteFooter";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { ArchiveIdentityBar } from "@/archived-components/_archived/archive/ArchiveIdentityBar";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import {
  ARCHIVE_COPY_RESTRAINT,
  ARCHIVE_SURFACE_EYEBROWS,
} from "@/lib/design/archive-copy-restraint";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { ACCOUNT_BACKUP, PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
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
import {
  DELETE_ACCOUNT_CONFIRM_PHRASE,
  DELETE_ACCOUNT_LEAD,
  PRIVATE_BY_DEFAULT_LINE,
} from "@/lib/trust-copy";
import { deleteServerAccountData } from "@/lib/account/delete-account";
import { runFullLocalReset } from "@/lib/data-controls";
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
  const { requestAuth } = useAuthPrompt();
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
  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [deleteLocalToo, setDeleteLocalToo] = useState(true);
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

  const handleDeleteAccount = async () => {
    if (!status.session) {
      showMessage("Sign in first to delete server account data.");
      return;
    }
    if (deleteConfirm.trim() !== DELETE_ACCOUNT_CONFIRM_PHRASE) {
      showMessage(`Type ${DELETE_ACCOUNT_CONFIRM_PHRASE} to confirm.`);
      return;
    }
    setBusy(true);
    try {
      const result = await deleteServerAccountData(true);
      if (!result.ok) {
        throw new Error(result.error ?? "Account deletion failed.");
      }
      await signOut();
      if (deleteLocalToo) {
        await runFullLocalReset();
      }
      setDeleteConfirm("");
      showMessage(result.message ?? "Server account data removed.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Account deletion failed.");
    } finally {
      setBusy(false);
    }
  };

  const runSync = async () => {
    setBusy(true);
    try {
      const ok = await syncNow();
      showMessage(
        ok ? "Encrypted backup saved." : "Backup paused. Nothing was deleted.",
      );
      if (ok) {
        void import("@/lib/monetization/monetization-observation").then((mod) => {
          mod.maybeTrackPostPremiumBehavior("backup");
        });
        void import("@/lib/retention/return-triggers").then((mod) => {
          mod.registerBackupReturnTrigger();
        });
      }
    } finally {
      setBusy(false);
    }
  };

  const handleSync = () => {
    if (!status.session) {
      requestAuth("sync_archive", () => void runSync());
      return;
    }
    void runSync();
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
        <PrimaryMain>
          <ArchivePageBlueprint
            surface="account"
            identity={{
              eyebrow: ARCHIVE_SURFACE_EYEBROWS.account,
              title: ARCHIVE_COPY_RESTRAINT.account.headline,
              lead: ARCHIVE_COPY_RESTRAINT.account.support,
            }}
            currentArchiveState={
              <>
                <ArchiveIdentityBar className={ARCHIVE_SPACE.sm} />
                <p className={ARCHIVE_TYPO.body}>{PRODUCT_WEDGE_LINE}</p>
                <ArchiveProtectionLine surface="account" />
              </>
            }
            mainContent={
              <>
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
              <SyncStatus />
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

              {hydrated && status.session ? (
                <div
                  className="space-y-3 border-t border-white/5 pt-4 text-sm leading-relaxed text-zinc-500"
                  data-testid="account-archive-ownership-v2"
                >
                  <ArchiveMilestones />
                  <ArchiveHistorySummary />
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
                <p className={ARCHIVE_TYPO.caption}>
                  Primary backup and restore actions are at the end of this page.
                </p>
              ) : (
                <div className="space-y-4 border-t border-white/5 pt-4">
                  <p className="text-zinc-500">{ACCOUNT_BACKUP.signInPrompt}</p>
                  <input
                    type="email"
                    id="account-email"
                    aria-label="Email address"
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
                    id="account-code"
                    aria-label="Sign-in code"
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
                <span>Include optional usage events in encrypted backup (off by default).</span>
              </label>
            </CardContent>
          </Card>
              </>
            }
            supportingContent={
              <>
                <details className="rounded-xl border border-white/10 bg-black/20">
                  <summary className="cursor-pointer px-4 py-3 text-sm text-zinc-400 marker:content-none [&::-webkit-details-marker]:hidden">
                    Supporting context
                  </summary>
                  <div className="space-y-3 border-t border-white/5 px-4 py-4">
                    <ArchiveAssetCard surface="account" showExportLink />
                    <ArchiveWorthStatement compact />
                  </div>
                </details>

          <section className="rounded-2xl border border-white/[0.06] bg-zinc-900/40 p-5">
            <h2 className={ARCHIVE_TYPO.cardTitle}>Delete account</h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-500">{DELETE_ACCOUNT_LEAD}</p>
            {status.session ? (
              <div className="mt-4 space-y-3">
                <label className="flex items-start gap-3 text-sm text-zinc-500">
                  <input
                    type="checkbox"
                    checked={deleteLocalToo}
                    onChange={(e) => setDeleteLocalToo(e.target.checked)}
                    className="mt-1"
                  />
                  <span>Also delete all local data on this device after server removal.</span>
                </label>
                <input
                  value={deleteConfirm}
                  onChange={(e) => setDeleteConfirm(e.target.value)}
                  placeholder={DELETE_ACCOUNT_CONFIRM_PHRASE}
                  aria-label={`Type ${DELETE_ACCOUNT_CONFIRM_PHRASE} to confirm deletion`}
                  className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-red-500/20 focus:ring-2"
                />
                <Button
                  variant="secondary"
                  disabled={busy || deleteConfirm.trim() !== DELETE_ACCOUNT_CONFIRM_PHRASE}
                  onClick={() => void handleDeleteAccount()}
                  className="border-red-500/30 text-red-300 hover:bg-red-500/10"
                >
                  Delete server account data
                </Button>
              </div>
            ) : (
              <p className="mt-3 text-sm text-zinc-500">Sign in to remove encrypted backup from our servers.</p>
            )}
            <Link
              href="/settings"
              className="mt-3 inline-block text-sm text-violet-300 hover:text-violet-200"
            >
              Delete all local data only →
            </Link>
          </section>

          <AccountSecondaryNav className={ARCHIVE_SPACE.md} />

          {message ? <p className={ARCHIVE_TYPO.body}>{message}</p> : null}

          <p className={ARCHIVE_TYPO.caption}>
            <Link href="/settings" className="underline underline-offset-4 hover:text-zinc-400">
              Settings
            </Link>
            {" · "}
            <Link href="/privacy" className="underline underline-offset-4 hover:text-zinc-400">
              Privacy
            </Link>
          </p>
              </>
            }
            actionArea={
              status.session ? (
                <ArchiveActionArea
                  primary={{
                    label: "Back up now",
                    onClick: () => handleSync(),
                    disabled: busy || status.state === "syncing",
                    testId: "account-primary-backup",
                  }}
                  secondary={{
                    label: "Restore backup",
                    onClick: () => void handleRestore(),
                    disabled: busy,
                  }}
                />
              ) : (
                <ArchiveActionArea
                  secondary={{
                    label: ACCOUNT_BACKUP.signInPrompt,
                    onClick: () => requestAuth("sync_archive", () => void runSync()),
                  }}
                />
              )
            }
          />
        </PrimaryMain>

        <SiteFooter className={ARCHIVE_SPACE.xl} />
      </div>
    </div>
  );
}
