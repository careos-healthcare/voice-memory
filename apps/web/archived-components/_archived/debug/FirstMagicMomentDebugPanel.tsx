"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { MagicMomentDebugReport } from "@/types/first-magic-moment";

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

export function FirstMagicMomentDebugPanel({ report }: { report: MagicMomentDebugReport }) {
  const { metrics } = report;

  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">First magic moment</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row
            label="Time until first meaningful callback"
            value={formatMs(metrics.timeUntilFirstMeaningfulCallbackMs)}
          />
          <Row label="Callback open rate" value={`${metrics.callbackOpenRate}%`} />
          <Row label="Candidates created" value={String(metrics.candidatesCreated)} />
          <Row label="Candidates shown" value={String(metrics.candidatesShown)} />
          <Row label="Candidates opened" value={String(metrics.candidatesOpened)} />
          <Row
            label="First recognition confirmed"
            value={
              metrics.firstMagicConfirmedAt
                ? `${metrics.firstMagicEngagement ?? "—"} · ${metrics.firstMagicConfirmedAt.slice(0, 16)}`
                : "—"
            }
          />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Qualified candidates (preview)</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm">
          {report.qualifications.length === 0 ? (
            <p className="text-zinc-500">No qualifying callbacks in current archive preview.</p>
          ) : (
            report.qualifications.map((row) => (
              <div key={row.noteId} className="border-b border-white/5 pb-3">
                <p className="text-zinc-400">{row.noteId}</p>
                <p className="mt-1 text-xs text-zinc-600">
                  {row.classification} · {row.qualityTotal} · {row.evidence.join(", ")}
                </p>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent events</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.recentEvents.length === 0 ? (
            <p className="text-zinc-500">No magic moment events yet.</p>
          ) : (
            report.recentEvents.map((event) => (
              <div key={`${event.name}-${event.at}`} className="border-b border-white/5 py-2">
                <p className="text-zinc-300">{event.name}</p>
                <p className="mt-1 text-xs text-zinc-600">
                  {event.at.slice(0, 16)}
                  {event.noteId ? ` · ${event.noteId}` : ""}
                  {event.surface ? ` · ${event.surface}` : ""}
                </p>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
