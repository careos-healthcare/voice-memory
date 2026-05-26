"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { RecurrenceDensityDebugPanel } from "@/components/debug/RecurrenceDensityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildRecurrenceDensityDebugReport } from "@/lib/debug/recurrence-density-review";
import type { RecurrenceDensityDebugReport } from "@/types/recurrence-density";

export default function RecurrenceDensityDebugPage() {
  const [report, setReport] = useState<RecurrenceDensityDebugReport | null>(null);

  const refresh = () => {
    setReport(buildRecurrenceDensityDebugReport());
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
              Recurrence density
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal week-one prompt gating — encourages repeated language without coaching,
              streaks, or tasks. Max one prompt per day. Not shown to users as scores.
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
            <RecurrenceDensityDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/first-week-funnel" className="text-violet-300 hover:text-violet-200">
            First-week funnel →
          </Link>
          <Link href="/debug/first-magic-moment" className="text-zinc-500 hover:text-zinc-300">
            First magic moment →
          </Link>
          <Link href="/debug/first-week-retention" className="text-zinc-500 hover:text-zinc-300">
            First-week retention →
          </Link>
          <Link href="/debug/silence-intelligence" className="text-zinc-500 hover:text-zinc-300">
            Quiet mode →
          </Link>
        </div>
      </div>
    </div>
  );
}
