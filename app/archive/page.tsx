"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Archive, Download, FileUp, RefreshCw, Trash2 } from "lucide-react";

import { ArchiveImportPreviewPanel } from "@/components/archive/ArchiveImportPreviewPanel";
import { useAccount } from "@/components/providers/AccountProvider";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { MotionPageTitle } from "@/components/motion/MotionPage";
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
import { getStoredEntryCount } from "@/lib/storage";
import type { ArchiveImportPreview, ArchiveRestoreMode } from "@/types/archive-permanence";

export default function ArchivePage() {
  const { status, restoreNow } = useAccount();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [entryCount, setEntryCount] = useState(0);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [preview, setPreview] = useState<ArchiveImportPreview | null>(null);
  const [restoreMode, setRestoreMode] = useState<ArchiveRestoreMode>("merge");
  const [includeSettings, setIncludeSettings] = useState(true);
  const [includeAudio, setIncludeAudio] = useState(true);

  const refreshCount = () => setEntryCount(getStoredEntryCount());

  useEffect(() => {
    refreshCount();
  }, []);

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 5000);
  };

  const handleExportAll = async () => {
    setBusy(true);
    try {
      const archive = await buildFullArchivePackage(true);
      downloadArchiveJson(archive);
      downloadArchiveMarkdown(buildArchiveMarkdown(archive));
      downloadArchiveZipPackage(archive);
      trackLaunchEvent(LAUNCH_EVENTS.exportUsed);
      showMessage("Archive exported as JSON, Markdown, and ZIP.");
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Export failed.");
    } finally {
      setBusy(false);
    }
  };

  const handleFileSelect = async (file: File | null) => {
    if (!file) return;
    setBusy(true);
    try {
      const parsed = await parseArchiveFile(file);
      const validated = validateArchiveImport(parsed);
      setPreview(validated);
      setIncludeAudio((validated.audioCount ?? 0) > 0);
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
      });
      refreshCount();
      setPreview(null);
      showMessage(
        `Restored ${result.entries} reflection${result.entries === 1 ? "" : "s"}${result.audio ? ` and ${result.audio} audio file${result.audio === 1 ? "" : "s"}` : ""}.`,
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
    const typed = window.prompt('Type DELETE to confirm permanent deletion.');
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

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <MotionPageTitle title="Archive" />

        <div className="mt-16 space-y-8">
          <Card className="border-white/[0.06] bg-zinc-900/40">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base font-normal text-zinc-200">
                <Archive className="h-4 w-4 text-violet-300/80" />
                Keep your reflections for years
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm leading-[1.75] text-zinc-500">
              <p>{ARCHIVE_PERMANENCE_COPY.neverTrapped}</p>
              <p>{ARCHIVE_PERMANENCE_COPY.takeWithYou}</p>
              <p className="text-zinc-600">{ARCHIVE_PERMANENCE_COPY.previewBeforeRestore}</p>
            </CardContent>
          </Card>

          <div className="flex flex-wrap gap-3">
            <Button disabled={busy || entryCount === 0} onClick={() => void handleExportAll()}>
              <Download className="h-4 w-4" />
              Export all
            </Button>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => fileInputRef.current?.click()}
            >
              <FileUp className="h-4 w-4" />
              Import archive
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".json,.zip,application/json,application/zip"
              className="hidden"
              onChange={(event) => void handleFileSelect(event.target.files?.[0] ?? null)}
            />
          </div>

          {preview ? (
            <div className="space-y-4">
              <ArchiveImportPreviewPanel
                preview={preview}
                mode={restoreMode}
                includeSettings={includeSettings}
                includeAudio={includeAudio}
                onModeChange={setRestoreMode}
                onIncludeSettingsChange={setIncludeSettings}
                onIncludeAudioChange={setIncludeAudio}
              />
              <Button
                disabled={busy || !preview.valid}
                onClick={() => void handleRestoreImport()}
              >
                Restore archive
              </Button>
            </div>
          ) : null}

          <Card className="border-white/[0.06] bg-zinc-900/40">
            <CardHeader>
              <CardTitle className="text-base font-normal text-zinc-200">
                Encrypted backup
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm leading-[1.75] text-zinc-500">
                {ARCHIVE_PERMANENCE_COPY.encryptedBackupPlaceholder}
              </p>
              <div className="flex flex-wrap gap-3">
                <Button
                  variant="secondary"
                  disabled={busy || status.state === "signed_out"}
                  onClick={() => void handleEncryptedRestore()}
                >
                  <RefreshCw className="h-4 w-4" />
                  Restore encrypted backup
                </Button>
                <Button asChild variant="ghost">
                  <Link href="/account">Account</Link>
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card className="border-red-500/20 bg-zinc-900/40">
            <CardHeader>
              <CardTitle className="text-base font-normal text-red-200/90">
                Delete archive on this device
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm leading-[1.75] text-zinc-500">
                {ARCHIVE_PERMANENCE_COPY.deleteWarning}
              </p>
              <Button
                variant="secondary"
                className="border-red-500/30 text-red-200 hover:bg-red-500/10"
                disabled={busy || entryCount === 0}
                onClick={() => void handleDeleteArchive()}
              >
                <Trash2 className="h-4 w-4" />
                Delete archive
              </Button>
            </CardContent>
          </Card>

          {message ? <p className="text-sm text-zinc-400">{message}</p> : null}

          <p className="text-sm text-zinc-600">
            <Link href="/settings" className="underline underline-offset-4 hover:text-zinc-400">
              Settings
            </Link>
            {" · "}
            <Link href="/export" className="underline underline-offset-4 hover:text-zinc-400">
              Other exports
            </Link>
          </p>
        </div>

        <SiteFooter className="mt-16" />
      </div>
    </div>
  );
}
