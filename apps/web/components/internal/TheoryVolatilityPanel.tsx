"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { TheoryVolatilityReport, TheoryVolatilityRiskLabel } from "@/types/theory";

interface TheoryVolatilityPanelProps {
  report: TheoryVolatilityReport;
}

function riskTone(label: TheoryVolatilityRiskLabel): string {
  switch (label) {
    case "healthy":
      return "border-emerald-500/30 bg-emerald-950/20 text-emerald-100";
    case "quiet":
      return "border-amber-500/25 bg-amber-950/15 text-amber-100";
    case "stale":
      return "border-orange-500/25 bg-orange-950/15 text-orange-100";
    case "dead_feed_risk":
      return "border-red-500/30 bg-red-950/20 text-red-100";
    default:
      return "border-white/10 bg-zinc-900/50 text-zinc-200";
  }
}

export function TheoryVolatilityPanel({ report }: TheoryVolatilityPanelProps) {
  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Theory Volatility</h2>
        <p className="mt-1 max-w-2xl text-sm leading-relaxed text-zinc-500">
          Local discover movement — whether the feed has enough change to support return visits.
        </p>
      </div>

      <Card className={`border ${riskTone(report.riskLabel)}`}>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium">Risk label</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold">{report.riskLabelDisplay}</p>
          <p className="mt-2 text-xs leading-relaxed opacity-80">
            {report.insightLines[0]}
          </p>
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Theories generated (peak)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.totalTheoriesGenerated}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Strengthened (cumulative)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.strengthenedCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Weakened (cumulative)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.weakenedCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Resolved / retired</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.resolvedCount} / {report.retiredCount}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Avg days between changes</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.averageDaysBetweenChanges ?? "—"}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Median days between changes</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.medianDaysBetweenChanges ?? "—"}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Zero-movement visits</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.zeroMovementVisits}
              <span className="ml-2 text-sm font-normal text-zinc-500">
                ({report.zeroMovementVisitRate}%)
              </span>
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Stale zero-movement sessions</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.staleZeroMovementSessions}
            </p>
            <p className="mt-1 text-xs text-zinc-600">
              Sessions with empty feed after 14+ days locally
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Readout</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {report.insightLines.map((line) => (
            <p key={line}>{line}</p>
          ))}
          <p className="pt-2 text-xs text-zinc-600">
            Discover visits tracked: {report.discoverVisitCount} · Movement events:{" "}
            {report.cumulativeMovementEvents}
            {report.daysSinceLastChange !== null
              ? ` · Days since last change: ${report.daysSinceLastChange}`
              : ""}
          </p>
        </CardContent>
      </Card>
    </section>
  );
}
