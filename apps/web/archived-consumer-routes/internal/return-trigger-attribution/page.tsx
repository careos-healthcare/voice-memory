"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ReturnTriggerPanel } from "@/archived-components/_archived/internal/ReturnTriggerPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { buildReturnTriggerAttributionReport } from "@/lib/internal/return-trigger-attribution-report";
import type { ReturnTriggerAttributionReport } from "@/types/return-trigger-attribution";

export default function ReturnTriggerAttributionPage() {
  const [report, setReport] = useState<ReturnTriggerAttributionReport | null>(null);

  const refresh = () => setReport(buildReturnTriggerAttributionReport());

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
              Return trigger attribution
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              What users say they came back for — and whether Discover met that expectation.
              Device-local measurement only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6">{report ? <ReturnTriggerPanel report={report} /> : null}</div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/retention-discovery" className="text-violet-300 hover:text-violet-200">
            Retention discovery →
          </Link>
          <Link href="/internal/retention-core" className="text-violet-300 hover:text-violet-200">
            Core retention →
          </Link>
        </div>
      </div>
    </div>
  );
}
