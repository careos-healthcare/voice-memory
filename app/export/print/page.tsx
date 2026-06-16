"use client";

import { useEffect, useState } from "react";

import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { PrintReportDocument } from "@/components/export/PrintReportDocument";
import {
  readPrintableReportFromSession,
  type PrintableReport,
} from "@/lib/memory-export";

export default function ExportPrintPage() {
  const [report, setReport] = useState<PrintableReport | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReport(readPrintableReportFromSession());
      setReady(true);
    });
    return () => cancelAnimationFrame(id);
  }, []);

  useEffect(() => {
    if (!ready || !report) return;

    const timer = window.setTimeout(() => {
      window.print();
    }, 400);

    return () => window.clearTimeout(timer);
  }, [ready, report]);

  if (!ready) {
    return (
      <PrimaryMain className="flex min-h-screen items-center justify-center bg-white text-sm text-zinc-700">
        <h1 className="sr-only">Print reflection report</h1>
        <p role="status">Preparing report…</p>
      </PrimaryMain>
    );
  }

  if (!report) {
    return (
      <PrimaryMain className="flex min-h-screen flex-col items-center justify-center gap-4 bg-white px-6 text-center">
        <h1 className="text-lg font-semibold text-zinc-900">Print reflection report</h1>
        <p className="text-sm text-zinc-900">No report data found.</p>
        <p className="text-xs text-zinc-800">
          Open Export from ArchiveMe and choose &ldquo;Print reflection report&rdquo;.
        </p>
      </PrimaryMain>
    );
  }

  return (
    <PrimaryMain className="min-h-screen bg-white print:bg-white">
      <h1 className="sr-only">Print reflection report</h1>
      <PrintReportDocument report={report} />
    </PrimaryMain>
  );
}
