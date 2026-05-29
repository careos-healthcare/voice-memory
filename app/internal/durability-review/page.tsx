"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { DurabilityReviewPanel } from "@/components/debug/DurabilityReviewPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildDurabilityReviewReport } from "@/lib/integrity/durability-review";
import type { DurabilityReviewReport } from "@/types/emotional-integrity-layer";

export default function DurabilityReviewDebugPage() {
  const [report, setReport] = useState<DurabilityReviewReport | null>(null);

  const refresh = () => {
    setReport(buildDurabilityReviewReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Consolidation</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Durability review
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Maintenance hotspots, sync and migration fragility, callback lineage risks, archive
              corruption signals, and future continuity gaps.
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
            <DurabilityReviewPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/emotional-integrity" className="text-violet-300 hover:text-violet-200">
            Emotional integrity →
          </Link>
          <Link href="/internal/archive-simplicity" className="text-zinc-500 hover:text-zinc-300">
            Archive simplicity →
          </Link>
          <Link href="/internal/archive-permanence" className="text-zinc-500 hover:text-zinc-300">
            Archive permanence →
          </Link>
        </div>
      </div>
    </div>
  );
}
