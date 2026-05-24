"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MoatMetricsReport } from "@/lib/retention/moat-metrics";

function MetricCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">{hint}</p>
      </CardContent>
    </Card>
  );
}

function FunnelTable({
  title,
  rows,
}: {
  title: string;
  rows: MoatMetricsReport["memoryLineFunnel"];
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <ul className="space-y-2">
          {rows.map((row) => (
            <li
              key={row.label}
              className="flex items-baseline justify-between gap-4 text-sm text-zinc-400"
            >
              <span>{row.label}</span>
              <span className="shrink-0 tabular-nums text-zinc-200">
                {row.count}
                {row.rateFromPrior ? (
                  <span className="ml-2 text-xs text-zinc-600">({row.rateFromPrior})</span>
                ) : null}
              </span>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}

export function MoatMetricsDebugPanel({ report }: { report: MoatMetricsReport }) {
  return (
    <div className="space-y-10">
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard
          label="Revisit → reflection (24h)"
          value={report.revisitToReflection24h}
          hint={`${report.revisitToReflection24hCount} of ${report.oldEntryRevisitCount} old-entry revisits`}
        />
        <MetricCard
          label="Revisit → reflection (7d)"
          value={report.revisitToReflection7d}
          hint={`${report.revisitToReflection7dCount} of ${report.oldEntryRevisitCount} old-entry revisits — primary moat metric`}
        />
        <MetricCard
          label="Old-entry revisit rate"
          value={report.oldEntryRevisitRate}
          hint={`${report.oldEntryRevisitCount} revisits across ${report.oldEntriesInArchive} old entries`}
        />
        <MetricCard
          label="Tracked revisits"
          value={String(report.oldEntryRevisitCount)}
          hint="Local old-entry reopen events with source and engagement flags"
        />
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        <FunnelTable title="Memory line → revisit → reflection" rows={report.memoryLineFunnel} />
        <FunnelTable title="Then vs now → reflection" rows={report.thenVsNowFunnel} />
        <FunnelTable title="Audio replay → reflection" rows={report.audioReplayFunnel} />
        <FunnelTable title="Bookmark / copy → reflection" rows={report.bookmarkCopyFunnel} />
      </section>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">
            Top memory lines → new reflections
          </CardTitle>
        </CardHeader>
        <CardContent>
          {report.topMemoryLines.length === 0 ? (
            <p className="text-sm text-zinc-500">No memory-line revisits with reflections yet.</p>
          ) : (
            <ul className="space-y-4">
              {report.topMemoryLines.map((row) => (
                <li key={row.noteId} className="space-y-1 border-b border-white/5 pb-4 last:border-0">
                  <p className="text-sm leading-relaxed text-zinc-300">{row.noteText}</p>
                  <p className="text-xs tabular-nums text-zinc-600">
                    {row.reflectionCount} reflection{row.reflectionCount === 1 ? "" : "s"} ·{" "}
                    {row.revisitCount} revisit{row.revisitCount === 1 ? "" : "s"} ·{" "}
                    {row.conversionRate}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">Recent revisit rows</CardTitle>
        </CardHeader>
        <CardContent>
          {report.revisits.length === 0 ? (
            <p className="text-sm text-zinc-500">No old-entry revisits tracked yet.</p>
          ) : (
            <ul className="space-y-3 text-xs text-zinc-500">
              {[...report.revisits]
                .reverse()
                .slice(0, 20)
                .map((row) => (
                  <li key={row.id} className="rounded-xl border border-white/5 px-3 py-2">
                    <p className="text-zinc-300">
                      {row.entryId.slice(0, 8)} · {row.sources || "unknown"}
                    </p>
                    <p className="mt-1 tabular-nums text-zinc-600">
                      {row.fromMemoryLine ? "memory line · " : ""}
                      {row.hadThenVsNow ? "then/now · " : ""}
                      {row.audioReplayed ? "audio · " : ""}
                      {row.bookmarkBeforeRecording ? "bookmark · " : ""}
                      {row.copyBeforeRecording ? "copy · " : ""}
                      {row.reflectionEntryId
                        ? `→ reflection ${row.reflectionEntryId.slice(0, 8)}`
                        : "→ no reflection yet"}
                    </p>
                  </li>
                ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
