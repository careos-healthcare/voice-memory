"use client";

import dynamic from "next/dynamic";
import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildPerformanceHealthReport,
  type PerformanceHealthReport,
} from "@/lib/debug/performance-health";

const PerformanceHealthPanel = dynamic(
  () =>
    import("@/components/debug/PerformanceHealthPanel").then(
      (mod) => mod.PerformanceHealthPanel,
    ),
  { ssr: false },
);

export default function PerformanceHealthDebugPage() {
  const [report, setReport] = useState<PerformanceHealthReport | null>(null);

  const refresh = () => {
    setReport(buildPerformanceHealthReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Performance</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Performance health
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal view of render churn, analytics queue pressure, resurfacing compute timings,
              and localStorage weight.
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
        ) : (
          <div className="mt-6">
            <PerformanceHealthPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/transcript-cleanup" className="text-violet-300 hover:text-violet-200">
            Transcript cleanup →
          </Link>
          <Link href="/debug/retention-core" className="text-zinc-500 hover:text-zinc-300">
            Retention core →
          </Link>
        </div>
      </div>
    </div>
  );
}
