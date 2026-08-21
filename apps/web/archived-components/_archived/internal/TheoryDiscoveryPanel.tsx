"use client";

import { useMemo } from "react";

import { NotificationEffectivenessPanel } from "@/archived-components/_archived/internal/NotificationEffectivenessPanel";
import { TheoryVolatilityPanel } from "@/archived-components/_archived/internal/TheoryVolatilityPanel";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { buildNotificationEffectivenessReport } from "@/lib/theories/notification-effectiveness";
import { THEORY_FEEDBACK_LABELS } from "@/lib/theories/theory-copy";
import type { TheoryDiscoveryReport } from "@/types/theory";

interface TheoryDiscoveryPanelProps {
  report: TheoryDiscoveryReport;
}

export function TheoryDiscoveryPanel({ report }: TheoryDiscoveryPanelProps) {
  const notificationReport = useMemo(
    () => buildNotificationEffectivenessReport(),
    [report.generatedAt],
  );

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Total theories</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.totalTheories}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Resolved</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.resolvedCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Retired</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.retiredCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Viewed</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.viewedTheories}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Revisit rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.revisitRate}%</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Changed theories</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.changedTheoryRate}%</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Feedback counts</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {(Object.keys(report.feedbackCounts) as Array<keyof typeof report.feedbackCounts>).map(
            (key) => (
              <p key={key}>
                {THEORY_FEEDBACK_LABELS[key]}: {report.feedbackCounts[key]}
              </p>
            ),
          )}
          <p className="mt-2 text-xs text-zinc-600">
            Expanded cards: {report.expandedTheories}
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Source breakdown</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {report.sourceBreakdown.map((row) => (
            <p key={row.source}>
              {row.source}: {row.count}
            </p>
          ))}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Strongest confidence increases</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-500">
            {report.strongestIncreases.length === 0 ? (
              <p className="text-zinc-600">None yet</p>
            ) : (
              report.strongestIncreases.map((row) => (
                <p key={row.theoryId}>
                  +{row.delta} — {row.statement}
                </p>
              ))
            )}
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Strongest confidence decreases</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-500">
            {report.strongestDecreases.length === 0 ? (
              <p className="text-zinc-600">None yet</p>
            ) : (
              report.strongestDecreases.map((row) => (
                <p key={row.theoryId}>
                  {row.delta} — {row.statement}
                </p>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <TheoryVolatilityPanel report={report.volatility} />

      <NotificationEffectivenessPanel report={notificationReport} />

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-violet-500/20 bg-violet-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-violet-100">Most “surprising”</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.mostSurprising.length === 0 ? (
              <p className="text-zinc-600">No feedback yet</p>
            ) : (
              report.mostSurprising.map((row) => (
                <p key={row.theoryId}>
                  {row.count}× — {row.statement}
                </p>
              ))
            )}
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-100">Most “not true”</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.mostNotTrue.length === 0 ? (
              <p className="text-zinc-600">No feedback yet</p>
            ) : (
              report.mostNotTrue.map((row) => (
                <p key={row.theoryId}>
                  {row.count}× — {row.statement}
                </p>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
