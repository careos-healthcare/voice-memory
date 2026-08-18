"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  RoundupLineMetricRow,
  RoundupObservationReport,
  RoundupPauseNoActionRow,
} from "@/types/roundup-observation";

function MetricTable({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: RoundupLineMetricRow[];
  empty: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          <ul className="space-y-3">
            {rows.map((row) => (
              <li key={row.lineKey} className="rounded-lg border border-white/[0.06] p-3">
                <p className="text-sm leading-relaxed text-zinc-300">{row.text}</p>
                <p className="mt-2 text-[10px] uppercase tracking-wider text-zinc-600">
                  {row.signal.replaceAll("_", " ")} · score {row.continuationScore}
                  {row.ignoreRatio > 0 ? ` · ignore ${Math.round(row.ignoreRatio * 100)}%` : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

function PauseTable({ rows }: { rows: RoundupPauseNoActionRow[] }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">Pause with no action</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">No pause-without-action cases yet.</p>
        ) : (
          <ul className="space-y-3">
            {rows.map((row) => (
              <li key={row.lineKey} className="rounded-lg border border-white/[0.06] p-3">
                <p className="text-sm leading-relaxed text-zinc-300">{row.text}</p>
                <p className="mt-2 text-[10px] uppercase tracking-wider text-zinc-600">
                  {row.pauseCount} pauses · {Math.round(row.dwellMs / 1000)}s dwell
                </p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function RoundupObservationDebugPanel({ report }: { report: RoundupObservationReport }) {
  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Opens
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.roundupOpens}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Instant abandons
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.instantAbandons}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Continuation conversion
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.continuationConversion}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Returns 24h / 7d
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.returns24h} / {report.returns7d}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <MetricTable
          title="Top continuation lines"
          rows={report.topContinuationLines}
          empty="No continuation signals yet."
        />
        <MetricTable
          title="Dead roundup lines"
          rows={report.deadRoundupLines}
          empty="No dead lines flagged yet."
        />
        <MetricTable
          title="Revisit-driving lines"
          rows={report.revisitDrivingLines}
          empty="No revisit-driven lines yet."
        />
        <MetricTable
          title="Copied lines"
          rows={report.copiedLines}
          empty="No copied roundup lines yet."
        />
        <MetricTable
          title="Bookmark-driving lines"
          rows={report.bookmarkDrivingLines}
          empty="No bookmark-driven lines yet."
        />
        <PauseTable rows={report.pauseWithNoAction} />
      </div>
    </div>
  );
}
