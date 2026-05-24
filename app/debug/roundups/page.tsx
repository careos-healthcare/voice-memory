"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { RoundupObservationDebugPanel } from "@/components/debug/RoundupObservationDebugPanel";
import { RoundupQualityDebugPanel } from "@/components/debug/RoundupQualityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildRoundupObservationReport } from "@/lib/debug/roundup-observation-review";
import { buildRoundupQualityReviewReport } from "@/lib/debug/roundup-quality-review";
import { getAllEntries } from "@/lib/storage";
import type { RoundupObservationReport } from "@/types/roundup-observation";
import type { RoundupQualityReviewReport } from "@/types/roundup-quality-review";

export default function RoundupsDebugPage() {
  const [qualityReport, setQualityReport] = useState<RoundupQualityReviewReport | null>(null);
  const [observationReport, setObservationReport] = useState<RoundupObservationReport | null>(null);

  const refresh = () => {
    setQualityReport(buildRoundupQualityReviewReport(getAllEntries()));
    setObservationReport(buildRoundupObservationReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  const loading = qualityReport === null || observationReport === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Roundup quality</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Roundup review</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Candidate quality, emotional payoff, and continuation signals — tune what lands without
              turning roundups into passive summaries.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {loading ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-12">
            {observationReport ? (
              <section className="space-y-4">
                <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Emotional payoff</h2>
                <RoundupObservationDebugPanel report={observationReport} />
              </section>
            ) : null}

            {qualityReport?.hasData ? (
              <section className="space-y-4">
                <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Quality guardrails</h2>
                <RoundupQualityDebugPanel report={qualityReport} onRefresh={refresh} />
              </section>
            ) : (
              <Card>
                <CardContent className="py-12 text-center text-sm text-zinc-500">
                  Add reflections to review roundup candidates.
                </CardContent>
              </Card>
            )}
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/roundups" className="text-zinc-500 hover:text-zinc-300">
            Roundups →
          </Link>
          <Link href="/debug/suppression" className="text-violet-300 hover:text-violet-200">
            Suppression review →
          </Link>
          <Link href="/debug/callbacks" className="text-violet-300 hover:text-violet-200">
            Memory lines →
          </Link>
        </div>
      </div>
    </div>
  );
}
