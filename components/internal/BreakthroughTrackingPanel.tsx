"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { BreakthroughTrackingReport } from "@/types/breakthrough-tracking";

interface BreakthroughTrackingPanelProps {
  report: BreakthroughTrackingReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function BreakthroughTrackingPanel({ report }: BreakthroughTrackingPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Breakthrough tracking (local)</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Real-world self-awareness and behavior change — lightweight prompts with attribution to
          blind spots, theories, notifications, and discover.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Breakthrough rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.breakthroughRate)}</p>
            <p className="mt-1 text-xs text-zinc-600">
              {report.totalBreakthroughs} yes / {report.totalPromptResponses} responses
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Per 100 insights</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.breakthroughsPer100Insights ?? "—"}
            </p>
            <p className="mt-1 text-xs text-zinc-600">
              {report.insightExposureCount} feedback exposures
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Per notification</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.breakthroughsPerNotification ?? "—"}
            </p>
            <p className="mt-1 text-xs text-zinc-600">
              {report.openedNotificationCount} opened notifications
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Yes breakthroughs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.totalBreakthroughs}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Breakthroughs per theory type</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-500">
          {report.byTheoryType.length === 0 ? (
            <p className="text-zinc-600">No attributed breakthroughs yet</p>
          ) : (
            report.byTheoryType.map((row) => (
              <p key={row.theoryType}>
                {row.theoryType}: {row.breakthroughs} ({row.perHundred ?? "—"} per 100 insights)
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">{report.winningInsightTitle}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.insightDimensions.map((row) => (
            <p key={row.dimension}>
              {row.label}: behavior change {rateLabel(row.behaviorChangeRate)} · breakthrough{" "}
              {rateLabel(row.breakthroughRate)} ({row.breakthroughYes}/{row.insightCount} with
              dimension)
            </p>
          ))}
          {report.lines.map((line) => (
            <p key={line} className="text-xs text-zinc-600">
              {line}
            </p>
          ))}
        </CardContent>
      </Card>
    </section>
  );
}
