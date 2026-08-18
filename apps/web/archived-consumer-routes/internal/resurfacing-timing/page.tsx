"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ResurfacingTimingDebugPanel } from "@/components/debug/ResurfacingTimingDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildResurfacingTimingDebugReport } from "@/lib/debug/resurfacing-timing-review";
import type { ResurfacingTimingDebugReport } from "@/types/resurfacing-timing";

export default function ResurfacingTimingDebugPage() {
  const [report, setReport] = useState<ResurfacingTimingDebugReport | null>(null);

  const refresh = () => {
    setReport(buildResurfacingTimingDebugReport());
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
              Resurfacing timing
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal timing gates — emotional distance, cooldowns, freshness decay, and
              post-processing suppression. Timing scores and classes never surface in product UI.
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
            <ResurfacingTimingDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/resurfacing-confidence" className="text-violet-300 hover:text-violet-200">
            Resurfacing confidence →
          </Link>
          <Link href="/internal/resurfacing-why-now" className="text-zinc-500 hover:text-zinc-300">
            Resurfacing why-now →
          </Link>
          <Link href="/internal/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callbacks →
          </Link>
        </div>
      </div>
    </div>
  );
}
