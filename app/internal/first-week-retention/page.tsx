"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { FirstWeekRetentionDebugPanel } from "@/components/debug/FirstWeekRetentionDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildFirstWeekRetentionDebugReport } from "@/lib/debug/first-week-retention";
import type { FirstWeekRetentionDebugReport } from "@/types/first-week-retention";

export default function FirstWeekRetentionDebugPage() {
  const [report, setReport] = useState<FirstWeekRetentionDebugReport | null>(null);

  const refresh = () => {
    setReport(buildFirstWeekRetentionDebugReport());
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
              First-week emotional return
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Calm return loops only — milestones, attachment emergence, prompt restraint, and
              meaningful revisit candidates. No streaks or habit pressure.
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
            <FirstWeekRetentionDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/first-week-funnel" className="text-violet-300 hover:text-violet-200">
            First-week funnel →
          </Link>
          <Link href="/internal/retention" className="text-zinc-500 hover:text-zinc-300">
            Retention dashboard →
          </Link>
          <Link href="/internal/return-triggers" className="text-zinc-500 hover:text-zinc-300">
            Return triggers →
          </Link>
          <Link href="/internal/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callbacks →
          </Link>
        </div>
      </div>
    </div>
  );
}
