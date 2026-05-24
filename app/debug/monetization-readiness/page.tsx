"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { MonetizationReadinessPanel } from "@/components/debug/MonetizationReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildMonetizationReadinessReport } from "@/lib/observation/monetization-readiness";
import type { MonetizationReadinessReport } from "@/types/observation-workflow";

export default function MonetizationReadinessPage() {
  const [report, setReport] = useState<MonetizationReadinessReport | null>(null);

  const refresh = () => {
    void buildMonetizationReadinessReport().then(setReport);
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
              Monetization readiness
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Gate for whether payment can be tested. No Stripe, no subscriptions, no pricing prompts.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Evaluating…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <MonetizationReadinessPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/moat-review" className="text-violet-300 hover:text-violet-200">
            Moat review →
          </Link>
          <Link href="/debug/production-readiness" className="text-violet-300 hover:text-violet-200">
            Production readiness →
          </Link>
          <Link href="/debug/callbacks" className="text-zinc-500 hover:text-zinc-300">
            Callback pruning →
          </Link>
        </div>
      </div>
    </div>
  );
}
