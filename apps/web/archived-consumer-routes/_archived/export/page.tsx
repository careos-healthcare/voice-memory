"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { AnimatedReveal } from "@/archived-components/_archived/motion/AnimatedReveal";
import {
  Download,
  FileJson,
  FileText,
  Printer,
} from "lucide-react";

import { useAuthPrompt } from "@/archived-components/_archived/auth/AuthPromptProvider";
import { UpgradeCta } from "@/archived-components/_archived/billing/UpgradeCta";
import { ArchiveAssetCard } from "@/archived-components/_archived/archive/ArchiveAssetCard";
import { ArchiveExportPreview } from "@/archived-components/_archived/archive/ArchiveExportPreview";
import { ArchiveWorthStatement } from "@/archived-components/_archived/archive/ArchiveWorthStatement";
import { EffortCompoundsPanel } from "@/archived-components/_archived/archive/EffortCompoundsPanel";
import { EvidenceLocker } from "@/archived-components/_archived/archive/EvidenceLocker";
import { ArchiveProtectionLine } from "@/archived-components/_archived/monetization/ArchiveProtectionLine";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { PrivacyNotice, TrustNotice } from "@/archived-components/_archived/system";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { requiresProForExportReports } from "@/lib/subscription";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { maybeTrackPostPremiumBehavior } from "@/lib/monetization/monetization-observation";
import { getEntries, getLockedEntryCount, getStoredEntryCount } from "@/lib/storage";
import {
  buildExportJsonBundle,
  buildPrintableReport,
  buildWeeklySummaryText,
  downloadJsonFile,
  downloadTextFile,
  openPrintableReport,
  slugExportDate,
} from "@/lib/memory-export";
import { downloadAccountPortabilityArchive } from "@/lib/account/account-data-portability";

export default function ExportPage() {
  const { requestAuth } = useAuthPrompt();
  const [entryCount, setEntryCount] = useState(0);
  const [storedCount, setStoredCount] = useState(0);
  const [lockedCount, setLockedCount] = useState(0);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const exportLocked = requiresProForExportReports();

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setEntryCount(getEntries().length);
      setStoredCount(getStoredEntryCount());
      setLockedCount(getLockedEntryCount());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const trackExport = () => {
    trackLaunchEvent(LAUNCH_EVENTS.exportUsed);
    maybeTrackPostPremiumBehavior("export");
  };

  const runExport = (fn: () => void) => {
    requestAuth("export", fn);
  };

  const exportAllJson = () => {
    runExport(() => {
      const bundle = buildExportJsonBundle();
      downloadJsonFile(`voicememory-all-${slugExportDate()}.json`, bundle);
      trackExport();
    });
  };

  const exportRangeJson = () => {
    runExport(() => {
      const bundle = buildExportJsonBundle(dateFrom, dateTo);
      downloadJsonFile(
        `voicememory-${dateFrom || "start"}-${dateTo || "end"}-${slugExportDate()}.json`,
        bundle,
      );
      trackExport();
    });
  };

  const exportWeeklyText = () => {
    if (exportLocked) return;
    runExport(() => {
      downloadTextFile(`voicememory-weekly-${slugExportDate()}.txt`, buildWeeklySummaryText());
      trackExport();
    });
  };

  const printReport = () => {
    if (exportLocked) return;
    runExport(() => {
      const report = buildPrintableReport({
        dateFrom,
        dateTo,
        maxExcerpts: 12,
      });
      openPrintableReport(report);
      trackExport();
    });
  };

  const exportAccountZip = () => {
    runExport(() => {
      void downloadAccountPortabilityArchive({
        dateFrom,
        dateTo,
        includePrintableReport: true,
      }).then(() => trackExport());
    });
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
        <AnimatedReveal className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-200">
            Export archive
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Take your evidence trail with you
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-muted">
            Download reflections, beliefs, timeline points, and top evidence quotes from
            this device. No account required for JSON; encrypted backup is separate.
          </p>
          <p className="mt-2 text-xs text-muted">
            {exportLocked
              ? `${entryCount} of ${storedCount} reflections exportable on Free`
              : `${entryCount} reflection${entryCount === 1 ? "" : "s"} available`}
            {lockedCount > 0 ? ` · ${lockedCount} locked on Pro` : null}
          </p>
        </AnimatedReveal>

        <ArchiveProtectionLine surface="export" />

        <ArchiveWorthStatement compact showCtas className="mt-4" />
        <ArchiveExportPreview className="mt-4" />
        <EvidenceLocker compact className="mt-4" />

        <UpgradeCta
          source="export"
          feature="export_reports"
          headline="Export reports are a Pro feature"
          description="Free can export JSON for your last 7 entries. Pro adds full-archive JSON, weekly summary text, and printable reflection reports with mood timelines and entity memory."
        />

        <TrustNotice className="mt-6">
          Exports include transcripts and reflections. Store files where you trust. ArchiveMe
          does not upload exports to any server.
        </TrustNotice>
        <PrivacyNotice className="mt-3" />
        <ArchiveAssetCard surface="export" showExportLink className="mt-4" />
        <EffortCompoundsPanel surface="export" className="mt-4" />

        <Card className="mt-6">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Date range (optional)</CardTitle>
            <p className="text-xs text-zinc-500">
              Used for JSON range export and printable reports
            </p>
          </CardHeader>
          <CardContent className="flex flex-col gap-3 sm:flex-row">
            <label className="flex min-w-0 flex-1 flex-col gap-1.5">
              <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                From
              </span>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
              />
            </label>
            <label className="flex min-w-0 flex-1 flex-col gap-1.5">
              <span className="text-[10px] font-medium uppercase tracking-wider text-muted">
                To
              </span>
              <input
                type="date"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
                className="w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
              />
            </label>
          </CardContent>
        </Card>

        <div className="mt-6 space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-center gap-2">
                <FileJson className="h-4 w-4 text-violet-300" />
                <CardTitle className="text-base">Archive JSON export</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="flex flex-col gap-3 sm:flex-row">
              <Button
                type="button"
                className="mobile-touch-target min-h-11 flex-1"
                onClick={exportAllJson}
                disabled={entryCount === 0}
              >
                <Download className="h-4 w-4" />
                All entries
              </Button>
              <Button
                type="button"
                variant="secondary"
                className="flex-1"
                onClick={exportRangeJson}
                disabled={entryCount === 0}
              >
                <FileJson className="h-4 w-4" />
                Date range
              </Button>
            </CardContent>
          </Card>

          <Card className="border-emerald-400/20 bg-gradient-to-br from-emerald-500/10 via-transparent to-transparent">
            <CardHeader className="pb-2">
              <div className="flex items-center gap-2">
                <Download className="h-4 w-4 text-emerald-300" />
                <CardTitle className="text-base">Full account export (ZIP)</CardTitle>
              </div>
              <p className="text-xs text-muted">
                Structured JSON, Markdown reflections, printable report snapshot, and archive
                attachment (beliefs, timeline, evidence locker)
              </p>
            </CardHeader>
            <CardContent>
              <Button
                type="button"
                className="mobile-touch-target min-h-11 w-full sm:w-auto"
                onClick={exportAccountZip}
                disabled={entryCount === 0}
              >
                <Download className="h-4 w-4" />
                Download ZIP
              </Button>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-center gap-2">
                <FileText className="h-4 w-4 text-emerald-300" />
                <CardTitle className="text-base">Weekly summary</CardTitle>
              </div>
              <p className="text-xs text-muted">Plain text · rolling 7-day summary</p>
            </CardHeader>
            <CardContent>
              <Button
                type="button"
                variant="secondary"
                onClick={exportWeeklyText}
                disabled={entryCount === 0 || exportLocked}
              >
                <Download className="h-4 w-4" />
                {exportLocked ? "Pro required" : "Download .txt"}
              </Button>
            </CardContent>
          </Card>

          <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
            <CardHeader className="pb-2">
              <div className="flex items-center gap-2">
                <Printer className="h-4 w-4 text-violet-300" />
                <CardTitle className="text-base">Printable reflection report</CardTitle>
              </div>
              <p className="text-xs text-muted">
                Mood timeline, themes, entities, weekly summary, and entry excerpts
              </p>
            </CardHeader>
            <CardContent className="space-y-3">
              <Button
                type="button"
                onClick={printReport}
                disabled={entryCount === 0 || exportLocked}
                className="w-full sm:w-auto"
              >
                <Printer className="h-4 w-4" />
                {exportLocked ? "Upgrade to print" : "Print reflection report"}
              </Button>
              <p className="text-xs text-muted">
                Opens a print-friendly tab. Use Save as PDF in your browser if you prefer a
                file.
              </p>
            </CardContent>
          </Card>
        </div>

        {entryCount === 0 ? (
          <p className="mt-8 text-center text-sm text-muted">
            <Link href="/" className="text-violet-200 hover:underline">
              Record a reflection
            </Link>{" "}
            to enable exports.
          </p>
        ) : null}
        </PrimaryMain>
      </div>
    </div>
  );
}
