"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { InsightScorecardReport } from "@/types/insight-scorecard";

interface InsightScorecardInternalPanelProps {
  report: InsightScorecardReport;
}

const SURFACE_LABELS: Record<string, string> = {
  blind_spot: "Blind spot",
  theory: "Theory",
  prediction: "Prediction",
  emerging_pattern: "Emerging pattern",
  discover: "Discover",
};

export function InsightScorecardInternalPanel({
  report,
}: InsightScorecardInternalPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Insight scorecard</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Recognition likelihood from existing feedback ingredients — prioritization layer only,
          not a new analysis engine.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Total scored</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.totalScored}</p>
            <p className="mt-1 text-xs text-zinc-600">
              Avg {report.averageScore ?? "—"}
            </p>
          </CardContent>
        </Card>
        <Card className="border-emerald-500/20 bg-emerald-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-emerald-100">Highest</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-xs text-zinc-500">
            {report.highest.length === 0 ? (
              <p className="text-zinc-600">None</p>
            ) : (
              report.highest.map((row) => (
                <p key={row.insightId}>
                  {row.score} ({row.scoreLabel}) — {row.headline.slice(0, 48)}
                </p>
              ))
            )}
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-100">Lowest</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-xs text-zinc-500">
            {report.lowest.length === 0 ? (
              <p className="text-zinc-600">None</p>
            ) : (
              report.lowest.map((row) => (
                <p key={row.insightId}>
                  {row.score} ({row.scoreLabel}) — {row.headline.slice(0, 48)}
                </p>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Average by surface</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-500">
          {report.bySurface.map((row) => (
            <p key={row.surface}>
              {SURFACE_LABELS[row.surface] ?? row.surface}: {row.averageScore ?? "—"} (
              {row.count})
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Ingredient hit rates</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-500">
          {report.ingredientHitRates.map((row) => (
            <p key={row.key}>
              {row.label}: {row.hitRate ?? "—"}% ({row.presentCount}/{report.totalScored})
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">Recommended priority order</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.recommendedPriorityOrder.slice(0, 8).map((row, index) => (
            <p key={row.insightId}>
              {index + 1}. [{row.surface}] {row.score} — {row.headline.slice(0, 56)}
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Breakthrough / reaction comparison</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-xs text-zinc-600">
          {report.breakthroughComparisonLines.map((line) => (
            <p key={line}>{line}</p>
          ))}
        </CardContent>
      </Card>
    </section>
  );
}
