"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { FirstMagicMomentDebugPanel } from "@/components/debug/FirstMagicMomentDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildFirstMagicMomentDebugReport } from "@/lib/debug/first-magic-moment-review";
import type { MagicMomentDebugReport } from "@/types/first-magic-moment";

export default function FirstMagicMomentDebugPage() {
  const [report, setReport] = useState<MagicMomentDebugReport | null>(null);

  const refresh = () => {
    setReport(buildFirstMagicMomentDebugReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              First magic moment
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal measurement only — when a specific callback from the user&apos;s own voice
              lands with recognition. Not shown to users.
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
            <FirstMagicMomentDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/return-triggers" className="text-violet-300 hover:text-violet-200">
            Return triggers →
          </Link>
          <Link href="/debug/revisit-quality" className="text-zinc-500 hover:text-zinc-300">
            Revisit quality →
          </Link>
          <Link href="/debug/onboarding-clarity" className="text-zinc-500 hover:text-zinc-300">
            Onboarding clarity →
          </Link>
        </div>
      </div>
    </div>
  );
}
