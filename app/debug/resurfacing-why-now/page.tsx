"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ResurfacingWhyNowDebugPanel } from "@/components/debug/ResurfacingWhyNowDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildResurfacingWhyNowDebugReport } from "@/lib/debug/resurfacing-why-now-review";
import type { ResurfacingWhyNowDebugReport } from "@/types/resurfacing-why-now";

export default function ResurfacingWhyNowDebugPage() {
  const [report, setReport] = useState<ResurfacingWhyNowDebugReport | null>(null);

  const refresh = () => {
    setReport(buildResurfacingWhyNowDebugReport());
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
              Resurfacing why-now
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal review of evidence-backed “why am I seeing this now?” lines. Every surfaced
              callback should carry a specific, non-coachy explanation — never therapy claims or
              numeric scores.
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
            <ResurfacingWhyNowDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/resurfacing-confidence" className="text-violet-300 hover:text-violet-200">
            Resurfacing confidence →
          </Link>
          <Link href="/debug/revisit-quality" className="text-zinc-500 hover:text-zinc-300">
            Revisit quality →
          </Link>
          <Link href="/debug/first-magic-moment" className="text-zinc-500 hover:text-zinc-300">
            First magic moment →
          </Link>
        </div>
      </div>
    </div>
  );
}
