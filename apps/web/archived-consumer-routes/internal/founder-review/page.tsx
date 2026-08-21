"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Download, RefreshCw } from "lucide-react";

import { FounderReviewPanel } from "@/archived-components/_archived/debug/FounderReviewPanel";
import { RememberedLaterPanel } from "@/archived-components/_archived/debug/RememberedLaterPanel";
import { ShareObservationPanel } from "@/archived-components/_archived/debug/ShareObservationPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  buildFounderReviewReport,
  downloadFounderReviewJson,
} from "@/lib/validation/founder-review";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import { buildObservationSummariesExport } from "@/lib/validation/observation-summaries";
import { getAllEntries } from "@/lib/storage";
import type { FounderReviewReport, ObservationSummariesExport } from "@/types/validation-phase";
import type { RememberedLaterReport } from "@/types/social-proof";
import type { ShareObservationReport } from "@/types/sharing";

export default function FounderReviewDebugPage() {
  const [report, setReport] = useState<FounderReviewReport | null>(null);
  const [summaries, setSummaries] = useState<ObservationSummariesExport | null>(null);
  const [rememberedLater, setRememberedLater] = useState<RememberedLaterReport | null>(null);
  const [shareObservation, setShareObservation] = useState<ShareObservationReport | null>(null);

  const refresh = async () => {
    const entries = getAllEntries();
    const [nextReport, nextSummaries] = await Promise.all([
      buildFounderReviewReport(),
      buildObservationSummariesExport(),
    ]);
    setReport(nextReport);
    setSummaries(nextSummaries);
    setRememberedLater(buildRememberedLaterReport(entries));
    setShareObservation(buildShareObservationReport());
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
          <div className="mt-6 space-y-6">
            {rememberedLater ? <RememberedLaterPanel report={rememberedLater} /> : null}
            {shareObservation ? <ShareObservationPanel report={shareObservation} /> : null}
            <FounderReviewPanel report={report} summaries={summaries} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/validation-ops" className="text-violet-300 hover:text-violet-200">
            Validation ops →
          </Link>
          <Link href="/internal/user-review" className="text-violet-300 hover:text-violet-200">
            User review →
          </Link>
          <Link href="/internal/distribution-readiness" className="text-violet-300 hover:text-violet-200">
            Distribution readiness →
          </Link>
          <Link href="/internal/social-proof-review" className="text-violet-300 hover:text-violet-200">
            Social proof review →
          </Link>
          <Link href="/internal/tester-feedback" className="text-violet-300 hover:text-violet-200">
            Tester feedback →
          </Link>
          <Link href="/internal/incidents" className="text-violet-300 hover:text-violet-200">
            Incidents →
          </Link>
          <Link href="/internal/retention-study" className="text-violet-300 hover:text-violet-200">
            Retention study →
          </Link>
          <Link href="/internal/monetization-readiness" className="text-violet-300 hover:text-violet-200">
            Monetization gate →
          </Link>
        </div>
      </div>
    </div>
  );
}
