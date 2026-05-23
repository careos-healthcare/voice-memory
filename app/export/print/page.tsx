"use client";

import { useEffect, useState } from "react";

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
      <div className="flex min-h-screen items-center justify-center bg-white text-sm text-zinc-600">
        Preparing report…
      </div>
    );
  }

  if (!report) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-white px-6 text-center">
        <p className="text-sm text-zinc-700">No report data found.</p>
        <p className="text-xs text-zinc-500">
          Open Export from VoiceMemory and choose &ldquo;Print reflection report&rdquo;.
        </p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white print:bg-white">
      <PrintReportDocument report={report} />
    </div>
  );
}
