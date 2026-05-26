"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  Download,
  FileJson,
  FileText,
  Printer,
  Shield,
} from "lucide-react";

import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { ArchiveProtectionLine } from "@/components/monetization/ArchiveProtectionLine";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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

export default function ExportPage() {
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

  const exportAllJson = () => {
    const bundle = buildExportJsonBundle();
    downloadJsonFile(`voicememory-all-${slugExportDate()}.json`, bundle);
    trackExport();
  };

  const exportRangeJson = () => {
    const bundle = buildExportJsonBundle(dateFrom, dateTo);
    downloadJsonFile(
      `voicememory-${dateFrom || "start"}-${dateTo || "end"}-${slugExportDate()}.json`,
      bundle,
    );
    trackExport();
  };

  const exportWeeklyText = () => {
    if (exportLocked) return;
    downloadTextFile(`voicememory-weekly-${slugExportDate()}.txt`, buildWeeklySummaryText());
    trackExport();
  };

  const printReport = () => {
    if (exportLocked) return;
    const report = buildPrintableReport({
      dateFrom,
      dateTo,
      maxExcerpts: 12,
    });
    openPrintableReport(report);
    trackExport();
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Export memory
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Take your memory with you
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Download or print your private memory layer from this device. No account,
            no cloud upload.
          </p>
          <p className="mt-2 text-xs text-zinc-500">
            {exportLocked
              ? `${entryCount} of ${storedCount} reflections exportable on Free`
              : `${entryCount} reflection${entryCount === 1 ? "" : "s"} available`}
            {lockedCount > 0 ? ` · ${lockedCount} locked on Pro` : null}
          </p>
        </motion.div>

        <ArchiveProtectionLine surface="export" />

        <UpgradeCta
          source="export"
          feature="export_reports"
          headline="Export reports are a Pro feature"
          description="Free can export JSON for your last 7 entries. Pro adds full-archive JSON, weekly summary text, and printable reflection reports with mood timelines and entity memory."
        />

        <div className="mt-6 flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
          <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
          <p className="text-xs leading-relaxed text-zinc-500">
            Exports include transcripts and reflections. Store files where you trust.
            VoiceMemory does not upload exports to any server.
          </p>
        </div>

        <Card className="mt-6">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Date range (optional)</CardTitle>
            <p className="text-xs text-zinc-500">
              Used for JSON range export and printable reports
            </p>
          </CardHeader>
          <CardContent className="flex flex-col gap-3 sm:flex-row">
            <label className="flex min-w-0 flex-1 flex-col gap-1.5">
              <span className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
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
              <span className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
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
                <CardTitle className="text-base">JSON export</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="flex flex-col gap-3 sm:flex-row">
              <Button
                type="button"
                className="flex-1"
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

          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-center gap-2">
                <FileText className="h-4 w-4 text-emerald-300" />
                <CardTitle className="text-base">Weekly summary</CardTitle>
              </div>
              <p className="text-xs text-zinc-500">Plain text · rolling 7-day summary</p>
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
              <p className="text-xs text-zinc-500">
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
              <p className="text-xs text-zinc-600">
                Opens a print-friendly tab. Use Save as PDF in your browser if you prefer a
                file.
              </p>
            </CardContent>
          </Card>
        </div>

        {entryCount === 0 ? (
          <p className="mt-8 text-center text-sm text-zinc-500">
            <Link href="/" className="text-violet-300 hover:underline">
              Record a reflection
            </Link>{" "}
            to enable exports.
          </p>
        ) : null}
      </div>
    </div>
  );
}
