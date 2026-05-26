"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import {
  RetentionFailuresCard,
  RetentionHealthBanner,
  RetentionReadoutCard,
} from "@/components/debug/RetentionReadoutCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildRetentionReadoutReport,
  type RetentionReadoutReport,
} from "@/lib/retention/retention-readout";

export default function RetentionReadoutDebugPage() {
  const [report, setReport] = useState<RetentionReadoutReport | null>(null);

  const refresh = () => {
    setReport(buildRetentionReadoutReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Retention readout
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Brutally honest behavior on this device — local analytics and session flags only.
              No dashboards, no vanity charts.
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
        ) : !report.hasData ? (
          <Card className="mt-6 border-dashed border-white/10">
            <CardContent className="py-12 text-center text-sm leading-relaxed text-zinc-500">
              No local retention data yet. Record a reflection, open a callback, then refresh.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-4">
            <Card className="border-white/[0.06] bg-zinc-900/30">
              <CardContent className="py-4 text-sm leading-relaxed text-zinc-500">
                {report.scopeNote} Updated {report.generatedAt.slice(0, 16)}.
              </CardContent>
            </Card>

            <RetentionHealthBanner health={report.health} headline={report.healthHeadline} />

            <RetentionFailuresCard
              lines={report.failures.lines}
              suppressedExamples={report.failures.suppressedExamples}
              neverOpenedIds={report.failures.neverOpenedIds}
            />

            <p className="text-xs uppercase tracking-wider text-zinc-600">Core metrics</p>
            <div className="grid gap-3 sm:grid-cols-2">
              {report.metrics.map((metric) => (
                <RetentionReadoutCard key={metric.label} title={metric.label} metric={metric} />
              ))}
            </div>

            {report.evidencePatterns.length > 0 ? (
              <>
                <p className="pt-2 text-xs uppercase tracking-wider text-zinc-600">
                  Top resurfacing evidence
                </p>
                <RetentionReadoutCard title="What repeats in the archive">
                  <ul className="space-y-3">
                    {report.evidencePatterns.map((row) => (
                      <li key={row.label} className="border-b border-white/5 pb-2 last:border-0">
                        <div className="flex justify-between gap-2">
                          <span className="text-zinc-300">{row.label}</span>
                          <span className="tabular-nums text-zinc-500">{row.count}</span>
                        </div>
                        {row.example ? (
                          <p className="mt-1 text-xs leading-relaxed text-zinc-600">
                            e.g. &ldquo;{row.example}&rdquo;
                          </p>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                </RetentionReadoutCard>
              </>
            ) : null}

            <p className="text-xs uppercase tracking-wider text-zinc-600">
              &ldquo;This remembers me&rdquo; signals
            </p>
            <div className="grid gap-3 sm:grid-cols-3">
              {report.remembersMe.map((metric) => (
                <RetentionReadoutCard key={metric.label} title={metric.label} metric={metric} />
              ))}
            </div>
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/retention-core" className="text-violet-300 hover:text-violet-200">
            Core metrics →
          </Link>
          <Link href="/debug/callback-learning" className="text-zinc-500 hover:text-zinc-300">
            Callback learning →
          </Link>
          <Link href="/" className="text-zinc-500 hover:text-zinc-300">
            Home →
          </Link>
        </div>
      </div>
    </div>
  );
}
