"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { CallbackQualityDebugPanel } from "@/components/debug/CallbackQualityDebugPanel";
import { SilenceTimingDebugPanel } from "@/components/debug/SilenceTimingDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildSilenceTimingDebugSnapshot, type SilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { getAllEntries } from "@/lib/storage";
import type { CallbackQualityReviewReport } from "@/types/callback-quality-review";

export default function CallbacksDebugPage() {
  const [report, setReport] = useState<CallbackQualityReviewReport | null>(null);
  const [silence, setSilence] = useState<SilenceTimingDebugSnapshot | null>(null);

  const refresh = () => {
    setReport(buildCallbackQualityReviewReport(getAllEntries()));
    setSilence(buildSilenceTimingDebugSnapshot());
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
            <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">
              Callback survival
            </p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
              Memory lines
            </h1>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-zinc-500">
              Find which exact memory lines survive emotionally after use. Track pauses, rereads,
              old-entry revisits, bookmarks, copied moments, follow-up continuations, and 24h/72h
              remembrance — then cut weak lines or double down on survivors.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
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
              Add a few reflections to review continuity callbacks.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-12 space-y-10">
            {silence ? <SilenceTimingDebugPanel snapshot={silence} /> : null}
            <CallbackQualityDebugPanel report={report} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/suppression" className="text-violet-300 hover:text-violet-200">
            Suppression review →
          </Link>
          <Link href="/debug/moat" className="text-violet-300 hover:text-violet-200">
            Moat metrics →
          </Link>
          <Link href="/debug/retention-loops" className="text-violet-300 hover:text-violet-200">
            Retention loops →
          </Link>
          <Link href="/debug/retention" className="text-violet-300 hover:text-violet-200">
            Retention dashboard →
          </Link>
          <Link href="/debug/changes" className="text-violet-300 hover:text-violet-200">
            Change debug →
          </Link>
          <Link href="/memory" className="text-zinc-500 hover:text-zinc-300">
            Memory →
          </Link>
        </div>
      </div>
    </div>
  );
}
