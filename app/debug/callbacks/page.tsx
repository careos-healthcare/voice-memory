"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { CallbackQualityDebugPanel } from "@/components/debug/CallbackQualityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { getAllEntries } from "@/lib/storage";
import type { CallbackQualityReviewReport } from "@/types/callback-quality-review";

export default function CallbacksDebugPage() {
  const [report, setReport] = useState<CallbackQualityReviewReport | null>(null);

  const refresh = () => {
    setReport(buildCallbackQualityReviewReport(getAllEntries()));
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">
              Callback quality review
            </p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
              Continuity moments
            </h1>
            <p className="mt-3 text-sm leading-relaxed text-zinc-500">
              Review surfaced callbacks with source evidence, interaction signals, and manual
              labels. Find which lines create pauses, rereads, and emotional recognition — not
              more feature breadth.
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
          <div className="mt-12">
            <CallbackQualityDebugPanel report={report} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
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
