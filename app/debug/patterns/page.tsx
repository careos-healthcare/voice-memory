"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { PatternSpecificityDebugPanel } from "@/components/debug/PatternSpecificityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildSpecificityDebugReport,
  type SpecificityDebugReport,
} from "@/lib/patterns/specificity-debug";
import { getAllEntries } from "@/lib/storage";

export default function PatternsDebugPage() {
  const [report, setReport] = useState<SpecificityDebugReport | null>(null);

  const refresh = () => {
    setReport(buildSpecificityDebugReport(getAllEntries(), 20));
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Pattern engine debug
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Pattern specificity
            </h1>
            <p className="mt-2 text-sm text-zinc-400">
              Local scoring for exact phrases, recurrence, cross-entry grounding,
              cross-week evidence, contradictions, entities, and date/time anchors.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Loading…
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Patterns scored
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-white">
                    {report.insights.length}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Avg specificity
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-white">
                    {report.averageSpecificity}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Strong
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-emerald-300">
                    {report.strongInsights.length}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Weak / generic
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-amber-300">
                    {report.weakInsights.length}
                  </p>
                </CardContent>
              </Card>
            </div>

            <PatternSpecificityDebugPanel insights={report.insights} />

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/changes" className="text-violet-300 hover:text-violet-200">
                Change detection →
              </Link>
              <Link href="/debug/retention" className="text-zinc-500 hover:text-zinc-300">
                Retention dashboard →
              </Link>
              <Link href="/insights" className="text-zinc-500 hover:text-zinc-300">
                Timeline →
              </Link>
              <Link href="/demo" className="text-zinc-500 hover:text-zinc-300">
                Demo mode →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
