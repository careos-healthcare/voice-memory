"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { RoundupQualityDebugPanel } from "@/components/debug/RoundupQualityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildRoundupQualityReviewReport } from "@/lib/debug/roundup-quality-review";
import { getAllEntries } from "@/lib/storage";
import type { RoundupQualityReviewReport } from "@/types/roundup-quality-review";

export default function RoundupsDebugPage() {
  const [report, setReport] = useState<RoundupQualityReviewReport | null>(null);

  const refresh = () => {
    setReport(buildRoundupQualityReviewReport(getAllEntries()));
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Roundup quality</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Roundup review</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Generated roundup candidates, suppressed lines, source entries, and quality reasons —
              keep reflective copy specific and quiet.
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
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Add reflections to review roundup candidates.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <RoundupQualityDebugPanel report={report} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/roundups" className="text-zinc-500 hover:text-zinc-300">
            Roundups →
          </Link>
          <Link href="/debug/suppression" className="text-violet-300 hover:text-violet-200">
            Suppression review →
          </Link>
          <Link href="/debug/callbacks" className="text-violet-300 hover:text-violet-200">
            Memory lines →
          </Link>
        </div>
      </div>
    </div>
  );
}
