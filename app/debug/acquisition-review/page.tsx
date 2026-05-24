"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { AcquisitionReviewPanel } from "@/components/debug/AcquisitionReviewPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildAcquisitionReviewReport } from "@/lib/debug/acquisition-review";
import type { AcquisitionReviewReport } from "@/types/acquisition-review";

export default function AcquisitionReviewDebugPage() {
  const [report, setReport] = useState<AcquisitionReviewReport | null>(null);

  const refresh = () => {
    setReport(buildAcquisitionReviewReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Store growth</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Acquisition review
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              ASO copy, screenshot sets, clarity checks, and first-session comprehension — debug
              only, no user-facing changes.
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
            <AcquisitionReviewPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/founder-review" className="text-violet-300 hover:text-violet-200">
            Founder review →
          </Link>
          <Link href="/welcome" className="text-zinc-500 hover:text-zinc-300">
            Welcome →
          </Link>
          <Link href="/how-it-works" className="text-zinc-500 hover:text-zinc-300">
            How it works →
          </Link>
        </div>
      </div>
    </div>
  );
}
