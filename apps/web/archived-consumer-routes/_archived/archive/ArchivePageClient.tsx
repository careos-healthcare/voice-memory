"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Archive, Download, FileUp, RefreshCw, Trash2 } from "lucide-react";

import { ArchiveImportPreviewPanel } from "@/components/archive/ArchiveImportPreviewPanel";
import { ArchiveOwnershipPanel } from "@/components/archive/ArchiveOwnershipPanel";
import { ArchiveSectionCard } from "@/components/archive/ArchiveSectionCard";
import { InsightShareCardExporter } from "@/components/archive/InsightShareCardExporter";
import { useAuthPrompt } from "@/components/auth/AuthPromptProvider";
import { useAccount } from "@/components/providers/AccountProvider";
import { SiteFooter } from "@/components/SiteFooter";
import { EmotionalProofLine } from "@/components/social-proof/EmotionalProofLine";
import { ArchiveProtectionLine } from "@/components/monetization/ArchiveProtectionLine";
import { maybeTrackPostPremiumBehavior } from "@/lib/monetization/monetization-observation";
import { pickPrimaryLifePeriod } from "@/lib/archive/life-periods";
import { ARCHIVE_PERMANENCE_COPY } from "@/lib/archive/copy";
import {
  buildFullArchivePackage,
  downloadArchiveJson,
  downloadArchiveMarkdown,
} from "@/lib/archive/full-export";
import { buildArchiveMarkdown } from "@/lib/archive/markdown-export";
import { deleteLocalArchive, restoreArchivePackage } from "@/lib/archive/restore-import";
import { parseArchiveFile, validateArchiveImport } from "@/lib/archive/validate-import";
import { downloadArchiveZipPackage } from "@/lib/archive/zip-package";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { trackArchiveUnderstood } from "@/lib/onboarding/onboarding-observation";
import { completeFirstSessionStep } from "@/lib/onboarding/first-session-flow";
import { getStoredEntryCount, getMemoryEligibleEntries } from "@/lib/storage";
import { EmptyState, LoadingState } from "@/components/system";
import { Button } from "@/components/ui/button";
import type { ArchiveImportPreview, ArchiveRestoreMode } from "@/types/archive-permanence";

export function ArchivePageClient() {
  const { requestAuth } = useAuthPrompt();
  const { status, restoreNow } = useAccount();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [ready, setReady] = useState(false);
  const [entryCount, setEntryCount] = useState(0);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [preview, setPreview] = useState<ArchiveImportPreview | null>(null);
  const [restoreMode, setRestoreMode] = useState<ArchiveRestoreMode>("merge");
  const [includeSettings, setIncludeSettings] = useState(true);
  const [includeAudio, setIncludeAudio] = useState(true);
  const [includePhotos, setIncludePhotos] = useState(true);
  const [lifePeriodLine, setLifePeriodLine] = useState<string | null>(null);
  const [lifePeriodWhen, setLifePeriodWhen] = useState<string | null>(null);

  const refreshCount = () => setEntryCount(getStoredEntryCount());

  useEffect(() => {
    refreshCount();
    const entries = getMemoryEligibleEntries();
    const note = pickPrimaryLifePeriod(entries);
    setLifePeriodLine(note?.text ?? null);
    setLifePeriodWhen(note?.currentDateLabel ?? note?.pastDateLabel ?? null);
    trackArchiveUnderstood("archive_page");
    completeFirstSessionStep("archive_perception");
    setReady(true);
  }, []);

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 5000);
  };

  const handleExportAll = async () => {
    const run = async () => {
    setBusy(true);
    try {
      const archive = await buildFullArchivePackage(true);
      downloadArchiveJson(archive);
      downloadArchiveMarkdown(buildArchiveMarkdown(archive));
      downloadArchiveZipPackage(archive);
      trackLaunchEvent(LAUNCH_EVENTS.exportUsed);
      void import("@/lib/retention/return-triggers").then((mod) => {
        mod.registerArchiveExportReturnTrigger("archive_page");
      });
      maybeTrackPostPremiumBehavior("export");
      showMessage("Archive exported as JSON, Markdown, and ZIP.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Export failed.");
    } finally {
      setBusy(false);
    }
    };
    if (!requestAuth("export", () => void run())) {
      return;
    }
    await run();
  };

  const handleFileSelect = async (file: File | null) => {
    if (!file) return;
    setBusy(true);
    try {
      const parsed = await parseArchiveFile(file);
      const validated = validateArchiveImport(parsed);
      setPreview(validated);
      setIncludeAudio((validated.audioCount ?? 0) > 0);
      setIncludePhotos((validated.photoCount ?? 0) > 0);
      if (!validated.valid) {
        showMessage("Archive could not be validated.");
      }
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Import failed.");
      setPreview(null);
    } finally {
      setBusy(false);
    }
  };

  const handleRestoreImport = async () => {
    if (!preview?.valid || !preview.package) return;

    if (restoreMode === "replace") {
      const typed = window.prompt(
        `Replace will delete all ${entryCount} reflection${entryCount === 1 ? "" : "s"} on this device.\n\nType DELETE to confirm.`,
      );
      if (typed !== "DELETE") return;
    }

    setBusy(true);
    try {
      const result = await restoreArchivePackage(preview.package, {
        mode: restoreMode,
        includeSettings,
        includeAudio,
        includePhotos,
      });
      refreshCount();
      setPreview(null);
      showMessage(
        `Restored ${result.entries} reflection${result.entries === 1 ? "" : "s"}${result.audio ? ` and ${result.audio} audio file${result.audio === 1 ? "" : "s"}` : ""}${result.photos ? ` and ${result.photos} photo${result.photos === 1 ? "" : "s"}` : ""}.`,
      );
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Restore failed.");
    } finally {
      setBusy(false);
    }
  };

  const handleDeleteArchive = async () => {
    if (
      !window.confirm(
        `Delete all ${entryCount} reflection${entryCount === 1 ? "" : "s"} and audio on this device? This cannot be undone.`,
      )
    ) {
      return;
    }
    const typed = window.prompt("Type DELETE to confirm permanent deletion.");
    if (typed !== "DELETE") return;

    setBusy(true);
    try {
      const removed = await deleteLocalArchive();
      refreshCount();
      setPreview(null);
      showMessage(`Deleted ${removed} reflection${removed === 1 ? "" : "s"}.`);
    } finally {
      setBusy(false);
    }
  };

  const handleEncryptedRestore = async () => {
    if (status.state === "signed_out") {
      showMessage("Sign in from Account to restore encrypted backup.");
      return;
    }
    setBusy(true);
    try {
      await restoreNow();
      refreshCount();
      showMessage("Restored from encrypted backup.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Encrypted restore failed.");
    } finally {
      setBusy(false);
    }
  };

  if (!ready) {
    return <LoadingState lines={4} label="Loading archive" className="py-12" />;
  }

  return (
    <div className="mt-10 space-y-6">
      <EmotionalProofLine surface="archive" />

      {entryCount === 0 ? (
        <EmptyState
          title="No reflections yet"
          description="Record a reflection first. Your archive grows on this device as you speak."
          action={
            <Link
              href="/record"
              className="mobile-touch-target inline-flex min-h-11 items-center rounded-full bg-violet-500/20 px-5 text-sm text-violet-200 ring-1 ring-violet-400/30"
            >
              Record
            </Link>
          }
        />
      ) : (
        <>
          {lifePeriodWhen ? (
            <p className="text-[10px] uppercase tracking-[0.2em] text-zinc-500">
              Period · {lifePeriodWhen}
            </p>
          ) : null}
          {lifePeriodLine ? (
            <p className="line-clamp-3 text-sm leading-relaxed text-zinc-400">{lifePeriodLine}</p>
          ) : null}

          <p className="text-xs text-zinc-500">
            {entryCount} reflection{entryCount === 1 ? "" : "s"} on this device
          </p>

          <InsightShareCardExporter />

          <details className="rounded-xl border border-white/10 bg-black/20">
            <summary className="cursor-pointer px-4 py-3 text-sm text-zinc-500 marker:content-none [&::-webkit-details-marker]:hidden">
              Ownership progress (detail)
            </summary>
            <div className="border-t border-white/5 px-4 py-4">
              <ArchiveOwnershipPanel />
            </div>
          </details>

          <ArchiveSectionCard
            title="Keep your reflections for years"
            icon={<Archive className="h-4 w-4 text-violet-300/80" />}
          >
            <p className="line-clamp-2">{ARCHIVE_PERMANENCE_COPY.neverTrapped}</p>
            <p className="line-clamp-2">{ARCHIVE_PERMANENCE_COPY.takeWithYou}</p>
            <p className="text-xs text-zinc-600">{ARCHIVE_PERMANENCE_COPY.previewBeforeRestore}</p>
          </ArchiveSectionCard>

          {preview?.valid ? (
            <ArchiveProtectionLine surface="restore" />
          ) : (
            <ArchiveProtectionLine surface="archive" />
          )}

          <div className="flex flex-wrap gap-2">
            <Button
              disabled={busy || entryCount === 0}
              className="mobile-touch-target min-h-11"
              onClick={() => void handleExportAll()}
            >
              <Download className="h-4 w-4" />
              Export all
            </Button>
            <Button
              variant="secondary"
              disabled={busy}
              className="mobile-touch-target min-h-11"
              onClick={() => fileInputRef.current?.click()}
            >
              <FileUp className="h-4 w-4" />
              Import
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".json,.zip,application/json,application/zip"
              className="hidden"
              aria-label="Import archive file"
              onChange={(event) => void handleFileSelect(event.target.files?.[0] ?? null)}
            />
          </div>

          {preview ? (
            <div className="space-y-3">
              <ArchiveImportPreviewPanel
                preview={preview}
                mode={restoreMode}
                includeSettings={includeSettings}
                includeAudio={includeAudio}
                includePhotos={includePhotos}
                onModeChange={setRestoreMode}
                onIncludeSettingsChange={setIncludeSettings}
                onIncludeAudioChange={setIncludeAudio}
                onIncludePhotosChange={setIncludePhotos}
              />
              <Button
                disabled={busy || !preview.valid}
                className="mobile-touch-target min-h-11"
                onClick={() => void handleRestoreImport()}
              >
                Restore archive
              </Button>
            </div>
          ) : null}

          <ArchiveSectionCard title="Encrypted backup">
            <p className="line-clamp-3">{ARCHIVE_PERMANENCE_COPY.encryptedBackupPlaceholder}</p>
            <div className="flex flex-wrap gap-2 pt-2">
              <Button
                variant="secondary"
                disabled={busy || status.state === "signed_out"}
                className="mobile-touch-target min-h-11"
                onClick={() => void handleEncryptedRestore()}
              >
                <RefreshCw className="h-4 w-4" />
                Restore encrypted backup
              </Button>
              <Button asChild variant="ghost" className="mobile-touch-target min-h-11">
                <Link href="/account">Account</Link>
              </Button>
            </div>
          </ArchiveSectionCard>

          <ArchiveSectionCard title="Delete archive on this device" tone="danger">
            <p className="line-clamp-3">{ARCHIVE_PERMANENCE_COPY.deleteWarning}</p>
            <Button
              variant="secondary"
              className="mobile-touch-target mt-2 min-h-11 border-red-500/30 text-red-200 hover:bg-red-500/10"
              disabled={busy || entryCount === 0}
              onClick={() => void handleDeleteArchive()}
            >
              <Trash2 className="h-4 w-4" />
              Delete archive
            </Button>
          </ArchiveSectionCard>
        </>
      )}

      {message ? (
        <p className="text-sm text-zinc-400" role="status">
          {message}
        </p>
      ) : null}

      <p className="text-sm text-zinc-500">
        <Link href="/settings" className="underline underline-offset-4 hover:text-zinc-400">
          Settings
        </Link>
        {" · "}
        <Link href="/export" className="underline underline-offset-4 hover:text-zinc-400">
          Other exports
        </Link>
      </p>

      <SiteFooter className="mt-10" />
    </div>
  );
}
