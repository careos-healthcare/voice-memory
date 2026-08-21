"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  ResurfacingTimingDebugReport,
  ResurfacingTimingReviewRow,
} from "@/types/resurfacing-timing";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function TimingRow({ row }: { row: ResurfacingTimingReviewRow }) {
  return (
    <div className="border-b border-white/5 py-2 text-sm">
      <p className="text-zinc-300">{row.text}</p>
      <p className="mt-1 text-xs text-zinc-500">
        {row.timingClass.replace(/_/g, " ")} · internal {row.timingScore}
        {row.timingEligible ? " · eligible" : " · suppressed"}
      </p>
      <p className="mt-1 text-xs text-zinc-600">
        {row.reasons.length > 0 ? row.reasons.join(" · ") : "no timing reasons"}
      </p>
      {row.suppressReasons.length > 0 ? (
        <p className="mt-1 text-xs text-amber-500/80">
          suppressed: {row.suppressReasons.join(" · ")}
        </p>
      ) : null}
      {row.nextEligibleAt ? (
        <p className="mt-1 text-xs text-zinc-600">
          next eligible: {new Date(row.nextEligibleAt).toLocaleString()}
        </p>
      ) : null}
    </div>
  );
}

function TimingList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: ResurfacingTimingReviewRow[];
  empty: string;
}) {
  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader>
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          rows.slice(0, 10).map((row) => <TimingRow key={row.noteId} row={row} />)
        )}
      </CardContent>
    </Card>
  );
}

export function ResurfacingTimingDebugPanel({
  report,
}: {
  report: ResurfacingTimingDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Candidates scored" value={String(report.totalCandidates)} />
          <Row label="Too early" value={String(report.byClass.too_early)} />
          <Row label="Cooling down" value={String(report.byClass.cooling_down)} />
          <Row label="Eligible" value={String(report.byClass.eligible)} />
          <Row label="Strong timing" value={String(report.byClass.strong_timing)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Top suppress reasons</CardTitle>
        </CardHeader>
        <CardContent>
          {report.topSuppressReasons.length === 0 ? (
            <p className="text-sm text-zinc-500">No suppressions recorded.</p>
          ) : (
            report.topSuppressReasons.map((item) => (
              <Row key={item.reason} label={item.reason.replace(/_/g, " ")} value={String(item.count)} />
            ))
          )}
        </CardContent>
      </Card>

      <TimingList title="Strong timing" rows={report.strongTiming} empty="No strong-timing callbacks." />
      <TimingList title="Eligible" rows={report.eligible} empty="No eligible callbacks." />
      <TimingList title="Cooling down" rows={report.coolingDown} empty="Nothing in cooldown." />
      <TimingList title="Too early" rows={report.tooEarly} empty="Nothing flagged too early." />
    </div>
  );
}
