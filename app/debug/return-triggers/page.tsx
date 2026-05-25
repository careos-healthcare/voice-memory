"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ReturnTriggersDebugPanel } from "@/components/debug/ReturnTriggersDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildReturnTriggersDebugReport } from "@/lib/debug/return-triggers-review";
import type { ReturnTriggerDebugReport } from "@/types/return-triggers";

export default function ReturnTriggersDebugPage() {
  const [report, setReport] = useState<ReturnTriggerDebugReport | null>(null);

  const refresh = () => {
    setReport(buildReturnTriggersDebugReport());
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
              Return triggers
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Internal attribution only — what preceded a return, how long the gap was, and
              whether the return led to reflection, revisit, or archive care. No user-facing
              dashboards.
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
            <ReturnTriggersDebugPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/first-week-retention" className="text-violet-300 hover:text-violet-200">
            First-week retention →
          </Link>
          <Link href="/debug/retention-loops" className="text-zinc-500 hover:text-zinc-300">
            Retention loops →
          </Link>
          <Link href="/debug/silence-intelligence" className="text-zinc-500 hover:text-zinc-300">
            Silence intelligence →
          </Link>
        </div>
      </div>
    </div>
  );
}
