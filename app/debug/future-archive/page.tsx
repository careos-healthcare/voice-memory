"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { FutureArchivePanel } from "@/components/debug/FutureArchivePanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildFutureArchiveSimulationReport } from "@/lib/debug/future-archive-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FutureArchiveSimulationReport } from "@/types/archive-permanence-layer";

export default function FutureArchiveDebugPage() {
  const [report, setReport] = useState<FutureArchiveSimulationReport | null>(null);

  const refresh = () => {
    setReport(buildFutureArchiveSimulationReport(getMemoryEligibleEntries()));
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Archive</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Future archive</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Years-later simulation — density, callback durability, revisit fatigue, landmark survival, and
              continuity drift. Debug only.
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
            <FutureArchivePanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/archive-permanence" className="text-violet-300 hover:text-violet-200">
            Archive permanence →
          </Link>
          <Link href="/debug/archive-maturity" className="text-zinc-500 hover:text-zinc-300">
            Archive maturity →
          </Link>
        </div>
      </div>
    </div>
  );
}
