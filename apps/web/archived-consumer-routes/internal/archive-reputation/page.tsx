"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveReputationPanel } from "@/components/internal/ArchiveReputationPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildArchiveReputationReport } from "@/lib/internal/archive-reputation-report";
import type { ArchiveReputationReport } from "@/lib/internal/archive-reputation-report";

export default function ArchiveReputationPage() {
  const [report, setReport] = useState<ArchiveReputationReport | null>(null);

  const refresh = () => setReport(buildArchiveReputationReport());

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Archive OS</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Archive reputation
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Reputation vs retention, conversion, attachment, and belief recall — from existing
              signals only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-8">
          <ArchiveReputationPanel />
        </div>

        {report ? (
          <p className="mt-4 text-xs text-zinc-600">
            Generated {report.generatedAt.slice(0, 19)} ·{" "}
            <Link href="/archive-belief" className="text-violet-300 hover:underline">
              Open archive belief
            </Link>
          </p>
        ) : null}
      </div>
    </div>
  );
}
