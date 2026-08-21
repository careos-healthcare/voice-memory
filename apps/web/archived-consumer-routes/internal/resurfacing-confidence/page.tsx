"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ResurfacingConfidenceDebugPanel } from "@/archived-components/_archived/debug/ResurfacingConfidenceDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { buildResurfacingConfidenceDebugReport } from "@/lib/debug/resurfacing-confidence-review";
import type { ResurfacingConfidenceDebugReport } from "@/types/resurfacing-confidence";

export default function ResurfacingConfidenceDebugPage() {
  const [report, setReport] = useState<ResurfacingConfidenceDebugReport | null>(null);

  const refresh = () => {
    setReport(buildResurfacingConfidenceDebugReport());
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
              Resurfacing confidence
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal scoring for whether callbacks feel earned — phrase recurrence, concern
              overlap, time gap, and interaction history. Classifications and numeric scores never
              surface in product UI; only quiet evidence reasons do.
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
            <ResurfacingConfidenceDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/resurfacing-timing" className="text-violet-300 hover:text-violet-200">
            Resurfacing timing →
          </Link>
          <Link href="/internal/resurfacing-why-now" className="text-zinc-500 hover:text-zinc-300">
            Resurfacing why-now →
          </Link>
          <Link href="/internal/revisit-quality" className="text-zinc-500 hover:text-zinc-300">
            Revisit quality →
          </Link>
          <Link href="/internal/first-magic-moment" className="text-zinc-500 hover:text-zinc-300">
            First magic moment →
          </Link>
          <Link href="/internal/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callbacks →
          </Link>
        </div>
      </div>
    </div>
  );
}
