"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { RECURRENCE_DENSITY_PROMPT_COPY } from "@/lib/retention/recurrence-density";
import type { RecurrenceDensityDebugReport } from "@/types/recurrence-density";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

export function RecurrenceDensityDebugPanel({
  report,
}: {
  report: RecurrenceDensityDebugReport;
}) {
  const { metrics, state, signals, previewOffer } = report;

  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Gating</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Within first week" value={report.withinFirstWeek ? "Yes" : "No"} />
          <Row label="Day index" value={report.dayIndex === null ? "—" : String(report.dayIndex)} />
          <Row label="Suppressed" value={metrics.suppressed ? "Yes" : "No"} />
          <Row label="Suppression reason" value={metrics.suppressionReason ?? "—"} />
          <Row label="Last shown day" value={state.lastShownDay ?? "—"} />
          <Row label="Dismissals" value={String(state.dismissedCount)} />
          <Row label="Shown this week" value={String(state.shownThisWeek)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Density metrics</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Entry count" value={String(metrics.entryCount)} />
          <Row label="Density score" value={`${Math.round(metrics.densityScore * 100)}%`} />
          <Row label="Recurring themes" value={String(metrics.recurringThemeCount)} />
          <Row label="Repeated phrases" value={String(metrics.repeatedPhraseCount)} />
          <Row label="Single-mention entities" value={String(metrics.singleMentionEntityCount)} />
          <Row label="Magic candidate yet" value={metrics.hasMagicCandidate ? "Yes" : "No"} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Detected signals</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm">
          {signals.length === 0 ? (
            <p className="text-zinc-500">No signals — prompt would not show.</p>
          ) : (
            signals.map((signal) => (
              <div key={signal.id} className="rounded-lg border border-white/5 bg-black/20 p-3">
                <p className="text-xs uppercase tracking-wider text-violet-300/80">
                  {signal.id} · priority {signal.priority}
                </p>
                <p className="mt-1 text-zinc-300">{signal.label}</p>
                <p className="mt-1 text-xs text-zinc-500">{signal.evidence}</p>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Preview offer</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {previewOffer ? (
            <>
              <p className="text-zinc-200">{previewOffer.text}</p>
              <p className="mt-2 text-xs text-zinc-500">
                {previewOffer.signalId} · {previewOffer.evidence}
              </p>
            </>
          ) : (
            <p className="text-zinc-500">No offer — gating or signals block surfacing.</p>
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Prompt copy bank</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {Object.entries(RECURRENCE_DENSITY_PROMPT_COPY).map(([id, text]) => (
            <p key={id}>
              <span className="text-zinc-600">{id}: </span>
              {text}
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent events</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-xs text-zinc-500">
          {report.recentEvents.length === 0 ? (
            <p>No recurrence-density events yet.</p>
          ) : (
            report.recentEvents.map((event) => (
              <p key={`${event.name}-${event.at}`}>
                {event.at.slice(0, 16)} · {event.name}
                {event.meta?.signalId ? ` · ${event.meta.signalId}` : ""}
              </p>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
