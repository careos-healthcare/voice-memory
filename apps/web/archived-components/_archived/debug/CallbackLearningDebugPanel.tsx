"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { CallbackLearningDebugReport } from "@/types/callback-learning";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

export function CallbackLearningDebugPanel({
  report,
}: {
  report: CallbackLearningDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Learned weights</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {Object.entries(report.weights).map(([kind, weight]) => (
            <Row key={kind} label={kind.replace(/_/g, " ")} value={String(weight)} />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Event counts</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Total tracked" value={String(report.totalEvents)} />
          {Object.entries(report.eventCounts).map(([event, count]) => (
            <Row key={event} label={event.replace(/_/g, " ")} value={String(count)} />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Top boosted kinds</CardTitle>
        </CardHeader>
        <CardContent>
          {report.topBoostedKinds.length === 0 ? (
            <p className="text-sm text-zinc-500">No positive learning yet.</p>
          ) : (
            report.topBoostedKinds.map((row) => (
              <Row key={row.kind} label={row.kind.replace(/_/g, " ")} value={String(row.weight)} />
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Top reduced kinds</CardTitle>
        </CardHeader>
        <CardContent>
          {report.topReducedKinds.length === 0 ? (
            <p className="text-sm text-zinc-500">No negative learning yet.</p>
          ) : (
            report.topReducedKinds.map((row) => (
              <Row key={row.kind} label={row.kind.replace(/_/g, " ")} value={String(row.weight)} />
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent events</CardTitle>
        </CardHeader>
        <CardContent>
          {report.recentEvents.length === 0 ? (
            <p className="text-sm text-zinc-500">No interaction events yet.</p>
          ) : (
            report.recentEvents.map((row) => (
              <div key={`${row.at}-${row.noteId}-${row.event}`} className="border-b border-white/5 py-2 text-sm">
                <p className="text-zinc-300">{row.event.replace(/_/g, " ")}</p>
                <p className="mt-1 text-xs text-zinc-500">{row.noteId}</p>
                <p className="mt-1 text-xs text-zinc-600">{row.kinds.join(" · ")}</p>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Sample rank adjustments</CardTitle>
        </CardHeader>
        <CardContent>
          {report.sampleAdjustments.length === 0 ? (
            <p className="text-sm text-zinc-500">No candidates to score.</p>
          ) : (
            report.sampleAdjustments.map((row) => (
              <div key={row.noteId} className="border-b border-white/5 py-2 text-sm">
                <p className="text-zinc-300">{row.text || row.noteId}</p>
                <p className="mt-1 text-xs text-zinc-500">
                  rank {row.rankAdjustment >= 0 ? "+" : ""}
                  {row.rankAdjustment} · interaction {row.interactionBoost >= 0 ? "+" : ""}
                  {row.interactionBoost}
                </p>
                <p className="mt-1 text-xs text-zinc-600">{row.kinds.join(" · ")}</p>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
