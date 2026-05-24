"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { TesterFeedbackPanel } from "@/components/debug/TesterFeedbackPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function TesterFeedbackDebugPage() {
  const [, setTick] = useState(0);

  const refresh = () => setTick((value) => value + 1);

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
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Tester feedback</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Lightweight feedback capture for real-user validation. Stored locally unless you export JSON.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6">
          <TesterFeedbackPanel />
        </div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/founder-review" className="text-violet-300 hover:text-violet-200">
            Founder review →
          </Link>
          <Link href="/debug/retention-study" className="text-violet-300 hover:text-violet-200">
            Retention study →
          </Link>
          <Link href="/welcome" className="text-zinc-500 hover:text-zinc-300">
            Tester welcome →
          </Link>
        </div>
      </div>
    </div>
  );
}
