"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Download, RefreshCw } from "lucide-react";

import { FounderReviewPanel } from "@/components/debug/FounderReviewPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildFounderReviewReport,
  downloadFounderReviewJson,
} from "@/lib/validation/founder-review";
import { buildObservationSummariesExport } from "@/lib/validation/observation-summaries";
import type { FounderReviewReport, ObservationSummariesExport } from "@/types/validation-phase";

export default function FounderReviewDebugPage() {
  const [report, setReport] = useState<FounderReviewReport | null>(null);
  const [summaries, setSummaries] = useState<ObservationSummariesExport | null>(null);

  const refresh = async () => {
    const [nextReport, nextSummaries] = await Promise.all([
      buildFounderReviewReport(),
      buildObservationSummariesExport(),
    ]);
    setReport(nextReport);
    setSummaries(nextSummaries);
  };

  useEffect(() => {
    void refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug only</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Founder review</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              One-page overview for real-user validation — ranked lists, no charts.
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <Button type="button" variant="ghost" size="sm" onClick={() => void refresh()}>
              <RefreshCw className="h-4 w-4" />
              Refresh
            </Button>
            {report ? (
              <Button type="button" variant="secondary" size="sm" onClick={() => downloadFounderReviewJson(report)}>
                <Download className="h-4 w-4" />
                Export JSON
              </Button>
            ) : null}
          </div>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Building review…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <FounderReviewPanel report={report} summaries={summaries} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/tester-feedback" className="text-violet-300 hover:text-violet-200">
            Tester feedback →
          </Link>
          <Link href="/debug/incidents" className="text-violet-300 hover:text-violet-200">
            Incidents →
          </Link>
          <Link href="/debug/retention-study" className="text-violet-300 hover:text-violet-200">
            Retention study →
          </Link>
          <Link href="/debug/monetization-readiness" className="text-violet-300 hover:text-violet-200">
            Monetization gate →
          </Link>
        </div>
      </div>
    </div>
  );
}
