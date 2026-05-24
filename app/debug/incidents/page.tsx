"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { IncidentsDebugPanel } from "@/components/debug/IncidentsDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildIncidentBundle, scanAndPersistIncidents } from "@/lib/validation/incidents";
import type { IncidentBundle } from "@/types/validation-phase";

export default function IncidentsDebugPage() {
  const [bundle, setBundle] = useState<IncidentBundle | null>(null);

  const refresh = () => {
    void buildIncidentBundle().then(setBundle);
  };

  useEffect(() => {
    void scanAndPersistIncidents().then(refresh);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-4xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug only</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Incidents</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Production incident reporting for sync, restore, audio, quota, and storage failures.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!bundle ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Scanning…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <IncidentsDebugPanel bundle={bundle} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/sync-health" className="text-violet-300 hover:text-violet-200">
            Sync health →
          </Link>
          <Link href="/debug/production-readiness" className="text-violet-300 hover:text-violet-200">
            Production readiness →
          </Link>
          <Link href="/debug/founder-review" className="text-violet-300 hover:text-violet-200">
            Founder review →
          </Link>
        </div>
      </div>
    </div>
  );
}
