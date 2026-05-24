"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ProductionReadinessPanel } from "@/components/debug/ProductionReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import type { ProductionReadinessReport } from "@/types/observation-workflow";

export default function ProductionReadinessPage() {
  const [report, setReport] = useState<ProductionReadinessReport | null>(null);

  const refresh = () => {
    void buildProductionReadinessReport().then(setReport);
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-4xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug only</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Production readiness
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Device and archive checks before real-user observation. Not shown outside debug.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Running checks…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <ProductionReadinessPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/monetization-readiness" className="text-violet-300 hover:text-violet-200">
            Monetization gate →
          </Link>
          <Link href="/debug/stress" className="text-violet-300 hover:text-violet-200">
            Stress tests →
          </Link>
          <Link href="/debug/sync-health" className="text-zinc-500 hover:text-zinc-300">
            Sync health →
          </Link>
        </div>
      </div>
    </div>
  );
}
