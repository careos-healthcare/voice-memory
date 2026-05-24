"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { LoopOptimizationDebugPanel } from "@/components/debug/LoopOptimizationDebugPanel";
import { MoatMetricsDebugPanel } from "@/components/debug/MoatMetricsDebugPanel";
import { RememberedLaterPanel } from "@/components/debug/RememberedLaterPanel";
import { ShareObservationPanel } from "@/components/debug/ShareObservationPanel";
import { ReopenPayoffDebugPanel } from "@/components/debug/ReopenPayoffDebugPanel";
import { SilenceTimingDebugPanel } from "@/components/debug/SilenceTimingDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildSilenceTimingDebugSnapshot, type SilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildReopenPayoffDebugReport, type ReopenPayoffDebugReport } from "@/lib/refinement/reopen-payoff";
import { buildLoopOptimizationReport, type LoopOptimizationReport } from "@/lib/retention/loop-optimization";
import {
  buildMoatMetricsReport,
  clearMoatMetrics,
  type MoatMetricsReport,
} from "@/lib/retention/moat-metrics";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import { getAllEntries } from "@/lib/storage";
import type { RememberedLaterReport } from "@/types/social-proof";
import type { ShareObservationReport } from "@/types/sharing";

export default function MoatDebugPage() {
  const [report, setReport] = useState<MoatMetricsReport | null>(null);
  const [silence, setSilence] = useState<SilenceTimingDebugSnapshot | null>(null);
  const [reopenPayoff, setReopenPayoff] = useState<ReopenPayoffDebugReport | null>(null);
  const [loopReport, setLoopReport] = useState<LoopOptimizationReport | null>(null);
  const [rememberedLater, setRememberedLater] = useState<RememberedLaterReport | null>(null);
  const [shareObservation, setShareObservation] = useState<ShareObservationReport | null>(null);

  const refresh = () => {
    const entries = getAllEntries();
    setReport(buildMoatMetricsReport());
    setSilence(buildSilenceTimingDebugSnapshot());
    setReopenPayoff(buildReopenPayoffDebugReport(entries));
    setLoopReport(buildLoopOptimizationReport(entries));
    setRememberedLater(buildRememberedLaterReport(entries));
    setShareObservation(buildShareObservationReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Moat metrics
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Archive alive
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local-only — whether old-entry revisits lead to new reflections within 24h and 7d.
              Primary moat metric: revisit → record again. Not shown to users.
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <Button type="button" variant="ghost" size="sm" onClick={refresh}>
              <RefreshCw className="h-4 w-4" />
              Refresh
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => {
                clearMoatMetrics();
                refresh();
              }}
            >
              Clear data
            </Button>
          </div>
        </header>

        {!report ? (
          <Card className="mt-12">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Loading…
            </CardContent>
          </Card>
        ) : !report.hasData ? (
          <Card className="mt-12">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Add reflections and revisit an older entry to start tracking moat metrics.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-12 space-y-10">
            {silence ? <SilenceTimingDebugPanel snapshot={silence} /> : null}
            {rememberedLater ? <RememberedLaterPanel report={rememberedLater} /> : null}
            {shareObservation ? <ShareObservationPanel report={shareObservation} /> : null}
            {reopenPayoff ? <ReopenPayoffDebugPanel report={reopenPayoff} /> : null}
            {loopReport?.hasData ? <LoopOptimizationDebugPanel report={loopReport} /> : null}
            <MoatMetricsDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/moat-review" className="text-violet-300 hover:text-violet-200">
            Moat review scoreboard →
          </Link>
          <Link href="/debug/retention-loops" className="text-violet-300 hover:text-violet-200">
            Retention loops →
          </Link>
          <Link href="/debug/callbacks" className="text-violet-300 hover:text-violet-200">
            Callback survival →
          </Link>
          <Link href="/memory" className="text-zinc-500 hover:text-zinc-300">
            Memory →
          </Link>
        </div>
      </div>
    </div>
  );
}
