"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadArchiveDepthJson } from "@/lib/debug/archive-maturity-review";
import type { ArchiveDepthReport } from "@/types/memory-compounding";

function ScoreCard({ label, value }: { label: string; value: number | string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
      </CardContent>
    </Card>
  );
}

export function ArchiveDepthPanel({ report }: { report: ArchiveDepthReport }) {
  const { signals } = report;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Archive meaning density — internal observation only, no user scoring.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadArchiveDepthJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <ScoreCard label="Density score" value={report.densityScore} />
        <ScoreCard label="Trend" value={report.densityTrend} />
        <ScoreCard label="Old-entry reuse" value={`${signals.oldEntryReuseRate}%`} />
        <ScoreCard label="Continuity survival" value={`${signals.continuitySurvivalScore}%`} />
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <ScoreCard label="Quote resurfacing" value={`${signals.quoteResurfacingRate}%`} />
        <ScoreCard label="Revisit depth" value={signals.revisitDepthScore} />
        <ScoreCard label="Delayed revisit→reflection" value={`${signals.delayedRevisitReflectionRate}%`} />
        <ScoreCard label="Copied reopened later" value={`${signals.copiedReopenedWeeksLaterRate}%`} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Weak archive zones</CardTitle>
          </CardHeader>
          <CardContent>
            {report.weakArchiveZones.length === 0 ? (
              <p className="text-sm text-zinc-500">No weak zones flagged.</p>
            ) : (
              <ul className="space-y-2">
                {report.weakArchiveZones.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300">
                    <p>{row.label}</p>
                    <p className="mt-1 text-xs text-zinc-600">{row.reason}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Strongest longitudinal callbacks</CardTitle>
          </CardHeader>
          <CardContent>
            {report.strongestLongitudinalCallbacks.length === 0 ? (
              <p className="text-sm text-zinc-500">Not enough archive depth yet.</p>
            ) : (
              <ul className="space-y-2">
                {report.strongestLongitudinalCallbacks.map((row) => (
                  <li key={row.id} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-300">
                    <p>{row.text}</p>
                    <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">score {row.score}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>

      {report.densityHistory.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Density trends</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="flex flex-wrap gap-3">
              {report.densityHistory.map((row) => (
                <li key={row.period} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-400">
                  {row.period}: <span className="tabular-nums text-zinc-200">{row.score}</span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
