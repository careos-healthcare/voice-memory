"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { RevisitQualityDebugPanel } from "@/components/debug/RevisitQualityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildRevisitQualityDebugReport } from "@/lib/debug/revisit-quality-review";
import type { RevisitQualityDebugReport } from "@/types/revisit-quality";

export default function RevisitQualityDebugPage() {
  const [report, setReport] = useState<RevisitQualityDebugReport | null>(null);

  const refresh = () => {
    setReport(buildRevisitQualityDebugReport());
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
              Revisit quality
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal scoring for whether revisits emotionally land — specificity, contrast,
              payoff, and fatigue risk. Classifications never surface in product UI.
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
            <RevisitQualityDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/return-triggers" className="text-violet-300 hover:text-violet-200">
            Return triggers →
          </Link>
          <Link href="/debug/retention-loops" className="text-zinc-500 hover:text-zinc-300">
            Retention loops →
          </Link>
          <Link href="/debug/callbacks" className="text-zinc-500 hover:text-zinc-300">
            Callbacks →
          </Link>
        </div>
      </div>
    </div>
  );
}
