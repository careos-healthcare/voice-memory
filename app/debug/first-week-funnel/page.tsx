"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { FirstWeekFunnelDebugPanel } from "@/components/debug/FirstWeekFunnelDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildFirstWeekFunnelDebugReport } from "@/lib/debug/first-week-funnel-review";
import type { FirstWeekFunnelDebugReport } from "@/types/first-week-funnel";

export default function FirstWeekFunnelDebugPage() {
  const [report, setReport] = useState<FirstWeekFunnelDebugReport | null>(null);

  const refresh = () => {
    setReport(buildFirstWeekFunnelDebugReport());
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
              First-week funnel
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal measurement only — whether users reach recognition, not just recording.
              Local-first. Not shown to users.
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
            <FirstWeekFunnelDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/first-magic-moment" className="text-violet-300 hover:text-violet-200">
            First magic moment →
          </Link>
          <Link href="/debug/first-week-retention" className="text-zinc-500 hover:text-zinc-300">
            First-week retention →
          </Link>
          <Link href="/debug/recurrence-density" className="text-zinc-500 hover:text-zinc-300">
            Recurrence density →
          </Link>
          <Link href="/debug/onboarding-clarity" className="text-zinc-500 hover:text-zinc-300">
            Onboarding clarity →
          </Link>
          <Link href="/debug/return-triggers" className="text-zinc-500 hover:text-zinc-300">
            Return triggers →
          </Link>
        </div>
      </div>
    </div>
  );
}
