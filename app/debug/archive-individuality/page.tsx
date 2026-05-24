"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveIndividualityPanel } from "@/components/debug/ArchiveIndividualityPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildArchiveIndividualityReviewReport } from "@/lib/debug/archive-individuality-review";
import type { ArchiveIndividualityReviewReport } from "@/types/archive-individuality";

export default function ArchiveIndividualityDebugPage() {
  const [report, setReport] = useState<ArchiveIndividualityReviewReport | null>(null);

  const refresh = () => {
    setReport(buildArchiveIndividualityReviewReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Individuality</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Archive individuality
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal profile of reflection style, pacing, silence rhythm, and vocabulary diversity.
              Prevents archives from converging. Exports archive-individuality-review.json.
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
            <ArchiveIndividualityPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/archive-divergence" className="text-violet-300 hover:text-violet-200">
            Archive divergence →
          </Link>
          <Link href="/debug/emotional-integrity" className="text-zinc-500 hover:text-zinc-300">
            Emotional integrity →
          </Link>
        </div>
      </div>
    </div>
  );
}
