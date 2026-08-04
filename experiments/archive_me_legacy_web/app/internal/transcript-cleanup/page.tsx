"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { TranscriptCleanupDebugPanel } from "@/components/debug/TranscriptCleanupDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildTranscriptCleanupDebugReport,
  type TranscriptCleanupDebugReport,
} from "@/lib/debug/transcript-cleanup-review";

export default function TranscriptCleanupDebugPage() {
  const [report, setReport] = useState<TranscriptCleanupDebugReport | null>(null);

  const refresh = () => {
    setReport(buildTranscriptCleanupDebugReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Transcript</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Transcript cleanup
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal review for filler removal, stutter collapse, pause normalization, and phrase
              preservation. Cleanup never summarizes or rewrites into polished prose.
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
            <TranscriptCleanupDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/resurfacing-confidence" className="text-violet-300 hover:text-violet-200">
            Resurfacing confidence →
          </Link>
          <Link href="/internal/transcript-cleanup" className="text-zinc-500 hover:text-zinc-300">
            Emotional recognition QA →
          </Link>
        </div>
      </div>
    </div>
  );
}
