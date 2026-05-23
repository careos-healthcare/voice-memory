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

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { getEntries } from "@/lib/storage";
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
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setEntryCount(getEntries().length);
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const exportAllJson = () => {
    const bundle = buildExportJsonBundle();
    downloadJsonFile(`voicememory-all-${slugExportDate()}.json`, bundle);
  };

  const exportRangeJson = () => {
    const bundle = buildExportJsonBundle(dateFrom, dateTo);
    downloadJsonFile(
      `voicememory-${dateFrom || "start"}-${dateTo || "end"}-${slugExportDate()}.json`,
      bundle,
    );
  };

  const exportWeeklyText = () => {
    downloadTextFile(`voicememory-weekly-${slugExportDate()}.txt`, buildWeeklySummaryText());
  };

  const printReport = () => {
    const report = buildPrintableReport({
      dateFrom,
      dateTo,
      maxExcerpts: 12,
    });
    openPrintableReport(report);
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
            Export
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Your memory, your file
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Download or print from localStorage on this device. Free — no account, no
            cloud upload.
          </p>
          <p className="mt-2 text-xs text-zinc-500">
            {entryCount} reflection{entryCount === 1 ? "" : "s"} available
          </p>
        </motion.div>

        <div className="mt-6 flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
          <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
          <p className="text-xs leading-relaxed text-zinc-500">
            Exports include journal text and reflections. Store files where you trust.
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
              <p className="text-xs text-zinc-500">Plain text · rolling 7-day intelligence</p>
            </CardHeader>
            <CardContent>
              <Button
                type="button"
                variant="secondary"
                onClick={exportWeeklyText}
                disabled={entryCount === 0}
              >
                <Download className="h-4 w-4" />
                Download .txt
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
                disabled={entryCount === 0}
                className="w-full sm:w-auto"
              >
                <Printer className="h-4 w-4" />
                Print reflection report
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
