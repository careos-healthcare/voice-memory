"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SilenceIntelligenceDebugPanel } from "@/components/debug/SilenceIntelligenceDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildSilenceIntelligenceReviewReport } from "@/lib/debug/silence-intelligence";
import type { SilenceIntelligenceDebugReport } from "@/types/silence-intelligence";

export default function SilenceIntelligenceDebugPage() {
  const [report, setReport] = useState<SilenceIntelligenceDebugReport | null>(null);

  const refresh = () => {
    setReport(buildSilenceIntelligenceReviewReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Restraint</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Silence intelligence
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              When the app should intentionally say less — state, signals, and suppression effects.
              Never hides saved entries or blocks recording.
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
            <SilenceIntelligenceDebugPanel report={report} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/suppression" className="text-violet-300 hover:text-violet-200">
            Suppression review →
          </Link>
          <Link href="/internal/revisit-quality" className="text-zinc-500 hover:text-zinc-300">
            Revisit quality →
          </Link>
          <Link href="/internal/return-triggers" className="text-zinc-500 hover:text-zinc-300">
            Return triggers →
          </Link>
        </div>
      </div>
    </div>
  );
}
