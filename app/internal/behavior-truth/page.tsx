"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { BehaviorTruthPanel } from "@/components/debug/BehaviorTruthPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildBehaviorTruthReport } from "@/lib/behavior/behavior-truth-report";
import type { BehaviorTruthReport } from "@/types/behavior-truth";

export default function BehaviorTruthDebugPage() {
  const [report, setReport] = useState<BehaviorTruthReport | null>(null);

  const refresh = () => {
    setReport(buildBehaviorTruthReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Behavioral truth
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local funnels and return patterns in plain language — not vanity charts. Use on
              real mobile after a few days of use.
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
          <Card className="mt-6 border-dashed border-white/10">
            <CardContent className="py-12 text-center text-sm leading-relaxed text-zinc-500">
              No local behavior data yet. Record, revisit a callback, then refresh.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-4">
            <Card className="border-white/[0.06] bg-zinc-900/30">
              <CardContent className="py-4 text-sm leading-relaxed text-zinc-500">
                {report.scopeNote} Updated {report.generatedAt.slice(0, 16)}.
              </CardContent>
            </Card>
            <BehaviorTruthPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/retention-core" className="text-violet-300 hover:text-violet-200">
            Retention readout →
          </Link>
          <Link href="/internal/retention-core" className="text-zinc-500 hover:text-zinc-300">
            Core metrics →
          </Link>
          <Link href="/internal/mobile-readiness" className="text-zinc-500 hover:text-zinc-300">
            Mobile readiness →
          </Link>
        </div>
      </div>
    </div>
  );
}
