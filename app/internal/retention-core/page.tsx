"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { RetentionCoreDashboard } from "@/components/debug/RetentionCoreDashboard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildRetentionCoreMetricsReport,
  type RetentionCoreMetricsReport,
} from "@/lib/debug/retention-core-metrics";

export default function RetentionCoreDebugPage() {
  const [report, setReport] = useState<RetentionCoreMetricsReport | null>(null);

  const refresh = () => {
    setReport(buildRetentionCoreMetricsReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Core retention metrics
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Real local signals from magic moment, callback learning, resurfacing confidence,
              return triggers, recurrence density, and first-week funnel — internal only, never
              shown to users.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : !report.hasData ? (
          <Card className="mt-6 border-dashed border-white/10">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              No retention data yet on this device. Record a reflection to start the funnel.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <RetentionCoreDashboard report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/first-magic-moment" className="text-violet-300 hover:text-violet-200">
            First magic moment →
          </Link>
          <Link href="/internal/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callback learning →
          </Link>
          <Link href="/internal/resurfacing-confidence" className="text-zinc-500 hover:text-zinc-300">
            Resurfacing confidence →
          </Link>
          <Link href="/internal/return-triggers" className="text-zinc-500 hover:text-zinc-300">
            Return triggers →
          </Link>
          <Link href="/internal/recurrence-density" className="text-zinc-500 hover:text-zinc-300">
            Recurrence density →
          </Link>
          <Link href="/internal/retention-core" className="text-zinc-500 hover:text-zinc-300">
            Retention readout →
          </Link>
          <Link href="/internal/first-week-funnel" className="text-zinc-500 hover:text-zinc-300">
            First-week funnel →
          </Link>
        </div>
      </div>
    </div>
  );
}
