"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ATierQualityDashboardPanel } from "@/archived-components/_archived/internal/ATierQualityDashboardPanel";
import { BlindSpotPerformancePanel } from "@/archived-components/_archived/internal/BlindSpotPerformancePanel";
import { buildATierQualityDashboardReport } from "@/lib/blind-spots/a-tier-quality-dashboard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { buildBlindSpotValidationReport } from "@/lib/blind-spots/blind-spot-metrics";
import type { ATierQualityDashboardReport } from "@/types/a-tier-prioritization";
import type { BlindSpotValidationReport } from "@/types/blind-spot";

export default function BlindSpotPerformancePage() {
  const [report, setReport] = useState<BlindSpotValidationReport | null>(null);
  const [aTierDashboard, setATierDashboard] = useState<ATierQualityDashboardReport | null>(() =>
    buildATierQualityDashboardReport(),
  );

  const refresh = () => {
    setReport(buildBlindSpotValidationReport(readAllBlindSpotFeedback()));
    setATierDashboard(buildATierQualityDashboardReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Validation</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Blind spot performance
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local reaction telemetry — measuring whether insights felt genuinely new (“How did it
              know that?”) versus generic agreement (“Yeah, I already knew that.”).
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
          <div className="mt-6 space-y-12">
            {aTierDashboard ? <ATierQualityDashboardPanel report={aTierDashboard} /> : null}
            <BlindSpotPerformancePanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link
            href="/internal/blind-spot-discovery"
            className="text-violet-300 hover:text-violet-200"
          >
            Discovery v2 →
          </Link>
          <Link href="/blind-spots" className="text-zinc-500 hover:text-zinc-300">
            Blind spot review →
          </Link>
          <Link href="/internal/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callback learning →
          </Link>
        </div>
      </div>
    </div>
  );
}
