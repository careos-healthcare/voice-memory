"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ChangeDebugPanel } from "@/components/debug/ChangeDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CHANGE_MIN_CONFIDENCE, buildChangeDebugReport } from "@/lib/patterns/changes";
import type { ChangeDebugReport } from "@/types/changes";
import { getAllEntries } from "@/lib/storage";

export default function ChangesDebugPage() {
  const [report, setReport] = useState<ChangeDebugReport | null>(null);

  const refresh = () => {
    setReport(buildChangeDebugReport(getAllEntries()));
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
            <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Change detection debug</p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
              Longitudinal changes
            </h1>
            <p className="mt-3 text-sm text-zinc-500">
              All candidate changes, scores, accept/reject reasons, and before/after evidence.
              Minimum to show: {CHANGE_MIN_CONFIDENCE}.
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
        ) : (
          <div className="mt-12 space-y-8">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Candidates
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-white">
                    {report.candidates.length}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Accepted
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-emerald-300">
                    {report.accepted.length}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Rejected
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-amber-300">
                    {report.rejected.length}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-1">
                  <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                    Avg confidence
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-semibold tabular-nums text-white">
                    {report.averageConfidence}
                  </p>
                </CardContent>
              </Card>
            </div>

            <ChangeDebugPanel candidates={report.candidates} />

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/patterns" className="text-violet-300 hover:text-violet-200">
                Pattern specificity →
              </Link>
              <Link href="/timeline" className="text-zinc-500 hover:text-zinc-300">
                Timeline →
              </Link>
              <Link href="/demo" className="text-zinc-500 hover:text-zinc-300">
                Demo →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
