"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveValuePanel } from "@/components/debug/ArchiveValuePanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildArchiveValueReviewReport } from "@/lib/debug/archive-value-review";
import type { ArchiveValueReviewReport } from "@/types/monetization-validation";

export default function ArchiveValueDebugPage() {
  const [report, setReport] = useState<ArchiveValueReviewReport | null>(null);

  const refresh = async () => {
    setReport(await buildArchiveValueReviewReport());
  };

  useEffect(() => {
    void refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Monetization</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Archive value</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Soft monetization validation — attachment signals, safest moments, trust risks, and WTP
              evolution. Debug only. No Stripe.
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
            <ArchiveValuePanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/validation-ops" className="text-violet-300 hover:text-violet-200">
            Validation ops →
          </Link>
          <Link href="/debug/monetization-readiness" className="text-zinc-500 hover:text-zinc-300">
            Monetization readiness →
          </Link>
        </div>
      </div>
    </div>
  );
}
