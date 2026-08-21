"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveAttachmentPanel } from "@/archived-components/_archived/internal/ArchiveAttachmentPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { buildArchiveAttachmentReport } from "@/lib/internal/archive-attachment-report";
import type { ArchiveAttachmentReport } from "@/types/archive-attachment";

export default function ArchiveAttachmentPage() {
  const [report, setReport] = useState<ArchiveAttachmentReport | null>(null);

  const refresh = () => setReport(buildArchiveAttachmentReport());

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Archive</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Archive attachment
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Whether users would miss this archive if it disappeared — not usage, but loss
              aversion. Shown at most once every 14 days after five reflections.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6">{report ? <ArchiveAttachmentPanel report={report} /> : null}</div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/retention-discovery" className="text-violet-300 hover:text-violet-200">
            Retention discovery →
          </Link>
          <Link href="/internal/archive-belief" className="text-violet-300 hover:text-violet-200">
            Archive belief →
          </Link>
        </div>
      </div>
    </div>
  );
}
