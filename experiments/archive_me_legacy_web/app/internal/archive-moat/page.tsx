"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveMoatReportPanel } from "@/components/internal/ArchiveMoatReportPanel";
import { InternalHubDecisionHeader } from "@/components/internal/InternalHubDecisionHeader";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildArchiveMoatReport, type ArchiveMoatReport } from "@/lib/internal/archive-moat-report";

export default function InternalArchiveMoatPage() {
  const [report, setReport] = useState<ArchiveMoatReport | null>(null);

  const refresh = () => setReport(buildArchiveMoatReport());

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />
      <div className="flex items-start justify-between gap-4">
        <InternalHubDecisionHeader
          route="/internal/archive-moat"
          title="Archive moat"
          subheadline="Archive loss test — do users believe this archive is replaceable?"
          eyebrow="Return & attachment"
        />
        <Button type="button" variant="ghost" size="sm" onClick={refresh}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="mt-8">
        {report ? <ArchiveMoatReportPanel report={report} /> : null}
      </div>

      <p className="mt-10 text-xs text-zinc-600">
        <Link href="/internal/return" className="hover:text-zinc-400">
          ← Return hub
        </Link>
      </p>
    </div>
  );
}
