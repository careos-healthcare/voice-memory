"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ATierQualityDashboardReport } from "@/types/a-tier-prioritization";

interface ATierQualityDashboardPanelProps {
  report: ATierQualityDashboardReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function ATierQualityDashboardPanel({ report }: ATierQualityDashboardPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">A-Tier quality dashboard</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Blind spots with contradictions, cost evidence, cross-life-area spread, and failed
          predictions outperform generic repetition. Rates are device-local.
        </p>
        {report.lowSampleWarning ? (
          <p className="mt-2 text-sm text-amber-200/90">Low sample — treat as directional.</p>
        ) : null}
        <p className="mt-2 text-xs text-zinc-600">{report.measurementNote}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-emerald-500/15 bg-emerald-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-emerald-100">A-tier rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.aTierRate)}</p>
          </CardContent>
        </Card>
        <Card className="border-violet-500/15 bg-violet-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-violet-100">B-tier rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.bTierRate)}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">C-tier rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.cTierRate)}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Outcomes by tier</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-zinc-400">
          {report.tierRows.map((row) => (
            <div
              key={row.tier}
              className="rounded-lg border border-white/5 bg-black/20 px-3 py-2"
            >
              <p className="font-medium text-zinc-300">
                {row.tierLabel} · n={row.count} · share {rateLabel(row.sharePercent)}
              </p>
              <p className="mt-1 text-xs text-zinc-500">
                Breakthrough {rateLabel(row.breakthroughRate)} · Pay conversion{" "}
                {rateLabel(row.payConversionRate)} · 7-day return{" "}
                {rateLabel(row.sevenDayReturnRate)}
              </p>
            </div>
          ))}
        </CardContent>
      </Card>
    </section>
  );
}
