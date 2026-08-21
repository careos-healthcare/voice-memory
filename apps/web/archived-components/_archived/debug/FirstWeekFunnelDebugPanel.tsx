"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { FUNNEL_STAGE_LABELS } from "@/lib/retention/first-week-funnel";
import type { FirstWeekFunnelDebugReport } from "@/types/first-week-funnel";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function formatMs(ms: number | null): string {
  if (ms === null) return "—";
  if (ms < 60_000) return `${Math.round(ms / 1000)}s`;
  if (ms < 86_400_000) return `${Math.round(ms / 3_600_000)}h`;
  return `${Math.round(ms / 86_400_000)}d`;
}

export function FirstWeekFunnelDebugPanel({ report }: { report: FirstWeekFunnelDebugReport }) {
  const { metrics } = report;

  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Funnel summary</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row
            label="Current stage"
            value={
              metrics.currentStage ? FUNNEL_STAGE_LABELS[metrics.currentStage] : "—"
            }
          />
          <Row
            label="Deepest linear stage"
            value={
              metrics.deepestLinearStage
                ? FUNNEL_STAGE_LABELS[metrics.deepestLinearStage]
                : "—"
            }
          />
          <Row label="Stages reached" value={String(metrics.stagesReached)} />
          <Row
            label="First visit → first reflection"
            value={formatMs(metrics.msFromFirstVisitToFirstReflection)}
          />
          <Row
            label="First reflection → resurfacing"
            value={formatMs(metrics.msFromFirstReflectionToResurfacing)}
          />
          <Row
            label="First reflection → magic moment"
            value={formatMs(metrics.msFromFirstReflectionToMagicMoment)}
          />
          <Row
            label="First visit → return 24h"
            value={formatMs(metrics.msFromFirstVisitToReturn24h)}
          />
          <Row
            label="First visit → return 7d"
            value={formatMs(metrics.msFromFirstVisitToReturn7d)}
          />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Stage timestamps</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.stages.map((row) => (
            <Row
              key={row.stage}
              label={row.label}
              value={row.at ? row.at.slice(0, 16) : "—"}
            />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recognition path</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {report.conversions.map((row) => (
            <div key={`${row.from}-${row.to}`} className="border-b border-white/5 py-2">
              <p className="text-zinc-400">
                {FUNNEL_STAGE_LABELS[row.from]} → {FUNNEL_STAGE_LABELS[row.to]}
              </p>
              <p className="mt-1 text-xs text-zinc-600">
                {row.reached ? "Reached" : "Not yet"} · step conversion {row.rate}%
              </p>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent funnel events</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.recentEvents.length === 0 ? (
            <p className="text-zinc-500">No funnel events yet.</p>
          ) : (
            report.recentEvents.map((event) => (
              <div key={`${event.stage}-${event.at}`} className="border-b border-white/5 py-2">
                <p className="text-zinc-300">{event.stage}</p>
                <p className="mt-1 text-xs text-zinc-600">{event.at.slice(0, 16)}</p>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
