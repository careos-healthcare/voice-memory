"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import {
  OpenLoopsHealthBanner,
  OpenLoopsReadoutMetricCard,
} from "@/components/debug/OpenLoopsReadoutCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildOpenLoopsReadoutReport,
  type OpenLoopsReadoutReport,
} from "@/lib/open-loops/open-loop-readout";

export default function OpenLoopsReadoutDebugPage() {
  const [report, setReport] = useState<OpenLoopsReadoutReport | null>(null);

  const refresh = () => {
    setReport(buildOpenLoopsReadoutReport());
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
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Open loops</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Open loops validation readout
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local loop storage plus open_loop_* events — emotional continuity validation only.
              Not exposed in the product.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6 flex flex-wrap gap-3 text-sm">
          <Link href="/open-loops" className="text-zinc-500 hover:text-zinc-300">
            Open loops →
          </Link>
          <Link href="/internal/retention-core" className="text-zinc-500 hover:text-zinc-300">
            Retention readout →
          </Link>
        </div>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : !report.hasData ? (
          <Card className="mt-6 border-dashed border-white/10">
            <CardContent className="py-12 text-center text-sm leading-relaxed text-zinc-500">
              No open loop data yet. Create a loop from an entry with unresolved language, then
              refresh.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <Card className="border-white/[0.06] bg-zinc-900/30">
              <CardContent className="py-4 text-sm leading-relaxed text-zinc-500">
                {report.scopeNote} Updated {report.generatedAt.slice(0, 16)}.
              </CardContent>
            </Card>

            <OpenLoopsHealthBanner health={report.health} headline={report.healthHeadline} />

            <p className="text-xs uppercase tracking-wider text-zinc-600">Core metrics</p>
            <div className="grid gap-3 sm:grid-cols-2">
              {report.metrics.map((metric) => (
                <OpenLoopsReadoutMetricCard key={metric.label} metric={metric} />
              ))}
            </div>

            <Card className="border-white/[0.06] bg-zinc-900/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-400">
                  Top anchor phrases
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-zinc-500">
                {report.topAnchorPhrases.length === 0 ? (
                  <p>None yet.</p>
                ) : (
                  report.topAnchorPhrases.map((row) => (
                    <p key={row.phrase}>
                      <span className="text-zinc-400">{row.count}×</span> {row.phrase}
                    </p>
                  ))
                )}
              </CardContent>
            </Card>

            <Card className="border-white/[0.06] bg-zinc-900/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-400">
                  Loops with no recurrence
                </CardTitle>
              </CardHeader>
              <CardContent className="text-sm text-zinc-500">
                {report.loopsWithNoRecurrence.length === 0 ? (
                  <p>Every loop has linked reflections beyond the source entry.</p>
                ) : (
                  <ul className="space-y-1">
                    {report.loopsWithNoRecurrence.map((title) => (
                      <li key={title}>{title}</li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>

            <Card className="border-white/[0.06] bg-zinc-900/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-400">
                  Resurfacing lines shown
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-zinc-500">
                {report.resurfacingLinesShown.length === 0 ? (
                  <p>None passed the evidence and genericity gates yet.</p>
                ) : (
                  report.resurfacingLinesShown.map((line) => (
                    <p key={line} className="leading-relaxed text-zinc-400">
                      {line}
                    </p>
                  ))
                )}
              </CardContent>
            </Card>

            <Card className="border-white/[0.06] bg-zinc-900/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-400">
                  Generic / suppressed candidates
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4 text-sm">
                {report.suppressedExamples.length === 0 ? (
                  <p className="text-zinc-500">No suppressed lines in the current audit.</p>
                ) : (
                  <>
                    <ul className="space-y-2 text-zinc-500">
                      {report.suppressedExamples.map((line) => (
                        <li key={line} className="leading-relaxed">
                          {line}
                        </li>
                      ))}
                    </ul>
                    {report.resurfacingAudits.map((audit) => (
                      <div
                        key={audit.openLoopId}
                        className="border-t border-white/[0.04] pt-3"
                      >
                        <p className="text-zinc-400">{audit.title}</p>
                        {audit.shown ? (
                          <p className="mt-1 text-zinc-500">Shown: {audit.shown}</p>
                        ) : null}
                        {audit.suppressed.length > 0 ? (
                          <p className="mt-1 text-zinc-600">
                            Suppressed: {audit.suppressed.join(" · ")}
                          </p>
                        ) : null}
                      </div>
                    ))}
                  </>
                )}
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}
