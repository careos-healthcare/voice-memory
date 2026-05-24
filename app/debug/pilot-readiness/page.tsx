"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { PilotReadinessPanel } from "@/components/debug/PilotReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildPilotReadinessReport } from "@/lib/pilot/pilot-readiness";
import type { PilotReadinessReport } from "@/types/pilot-system";

export default function PilotReadinessDebugPage() {
  const [report, setReport] = useState<PilotReadinessReport | null>(null);

  const refresh = async () => {
    setReport(await buildPilotReadinessReport());
  };

  useEffect(() => {
    void refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-4xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Pilot</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Pilot readiness</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Founder readiness gate before charging — attachment, trust, sync, archive maturity. Debug only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={() => void refresh()}>
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
            <PilotReadinessPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/pilot-review" className="text-violet-300 hover:text-violet-200">
            Pilot review →
          </Link>
          <Link href="/debug/archive-value" className="text-zinc-500 hover:text-zinc-300">
            Archive value →
          </Link>
        </div>
      </div>
    </div>
  );
}
