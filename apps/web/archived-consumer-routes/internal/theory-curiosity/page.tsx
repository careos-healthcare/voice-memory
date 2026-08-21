"use client";

import { useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { TheoryCuriosityEnginePanel } from "@/archived-components/_archived/internal/TheoryCuriosityEnginePanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { buildTheoryCuriosityEngineReport } from "@/lib/metrics/theory-curiosity-engine";
import type { TheoryCuriosityEngineReport } from "@/types/theory-curiosity-engine";

export default function TheoryCuriosityPage() {
  const [report, setReport] = useState<TheoryCuriosityEngineReport | null>(() =>
    buildTheoryCuriosityEngineReport(),
  );

  const refresh = () => setReport(buildTheoryCuriosityEngineReport());

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Theory Curiosity Engine
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Leading indicator readout — curiosity before open, then discover, return, paywall,
              and subscription. No streaks or reminder pressure.
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
            <TheoryCuriosityEnginePanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/discover" className="text-violet-300 hover:text-violet-200">
            Discover →
          </Link>
          <Link href="/internal/theory-discovery" className="text-zinc-500 hover:text-zinc-300">
            Theory discovery →
          </Link>
        </div>
      </div>
    </div>
  );
}
