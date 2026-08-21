"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SurfacePrimaryPanel } from "@/archived-components/_archived/internal/SurfacePrimaryPanel";
import { EvolvingUnderstandingPanel } from "@/archived-components/_archived/internal/EvolvingUnderstandingPanel";
import { TheoryCuriosityEnginePanel } from "@/archived-components/_archived/internal/TheoryCuriosityEnginePanel";
import { TheoryDiscoveryPanel } from "@/archived-components/_archived/internal/TheoryDiscoveryPanel";
import { buildEvolvingUnderstandingReport } from "@/lib/metrics/evolving-understanding-report";
import { buildTheoryCuriosityEngineReport } from "@/lib/metrics/theory-curiosity-engine";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { buildSurfacePrimaryReport } from "@/lib/discover/surface-primary-report";
import { buildTheoryDiscoveryReport } from "@/lib/theories/theory-discovery-report";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { SurfacePrimaryReport, TheoryDiscoveryReport } from "@/types/theory";

export default function TheoryDiscoveryPage() {
  const entries = useMemo(() => getMemoryEligibleEntries(), []);
  const [report, setReport] = useState<TheoryDiscoveryReport | null>(null);
  const [surfaceReport, setSurfaceReport] = useState<SurfacePrimaryReport | null>(null);
  const [curiosityReport, setCuriosityReport] = useState(() =>
    buildTheoryCuriosityEngineReport(),
  );
  const [evolvingReport, setEvolvingReport] = useState(() =>
    buildEvolvingUnderstandingReport(),
  );

  const refresh = () => {
    setReport(buildTheoryDiscoveryReport(entries));
    setSurfaceReport(buildSurfacePrimaryReport());
    setCuriosityReport(buildTheoryCuriosityEngineReport());
    setEvolvingReport(buildEvolvingUnderstandingReport());
  };

  useEffect(() => {
    refresh();
  }, [entries]);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Theories</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Theory discovery
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal readout for working theories — views, feedback, confidence shifts, and
              source mix. Measurement only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report || !surfaceReport ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-12">
            <EvolvingUnderstandingPanel report={evolvingReport} />
            <TheoryCuriosityEnginePanel report={curiosityReport} />
            <SurfacePrimaryPanel report={surfaceReport} />
            <TheoryDiscoveryPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/discover" className="text-violet-300 hover:text-violet-200">
            Discover feed →
          </Link>
          <Link href="/theories" className="text-violet-300 hover:text-violet-200">
            Theories surface →
          </Link>
          <Link href="/internal/theory-curiosity" className="text-violet-300 hover:text-violet-200">
            Theory curiosity engine →
          </Link>
          <Link href="/internal/blind-spot-discovery" className="text-zinc-500 hover:text-zinc-300">
            Blind spot discovery →
          </Link>
        </div>
      </div>
    </div>
  );
}
