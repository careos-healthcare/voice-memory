"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchivePermanencePanel } from "@/components/debug/ArchivePermanencePanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildArchivePermanenceReviewReport } from "@/lib/debug/archive-permanence-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchivePermanenceReviewReport } from "@/types/archive-permanence-layer";

export default function ArchivePermanenceDebugPage() {
  const [report, setReport] = useState<ArchivePermanenceReviewReport | null>(null);

  const refresh = () => {
    setReport(buildArchivePermanenceReviewReport(getMemoryEligibleEntries()));
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
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Archive permanence</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Founder review — permanent callbacks, continuity break risks, migration guarantees, landmarks,
              and life periods. Debug only.
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
            <ArchivePermanencePanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/future-archive" className="text-violet-300 hover:text-violet-200">
            Future archive →
          </Link>
          <Link href="/debug/archive-depth" className="text-zinc-500 hover:text-zinc-300">
            Archive depth →
          </Link>
        </div>
      </div>
    </div>
  );
}
