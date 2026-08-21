"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  ResurfacingWhyNowDebugReport,
  ResurfacingWhyNowReviewRow,
} from "@/types/resurfacing-why-now";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function WhyNowRow({ row }: { row: ResurfacingWhyNowReviewRow }) {
  return (
    <div className="border-b border-white/5 py-2 text-sm">
      <p className="text-zinc-300">{row.text}</p>
      {row.explanation ? (
        <p className="mt-1 text-xs text-violet-300/85">{row.explanation}</p>
      ) : (
        <p className="mt-1 text-xs text-amber-500/80">No evidence-backed explanation</p>
      )}
      <p className="mt-1 text-xs text-zinc-500">
        {row.primaryKind ? row.primaryKind.replace(/_/g, " ") : "—"} · {row.signalCount} signal
        {row.signalCount === 1 ? "" : "s"}
      </p>
      {row.signals.length > 0 ? (
        <p className="mt-1 text-xs text-zinc-600">
          {row.signals
            .slice(0, 3)
            .map((signal) => signal.kind.replace(/_/g, " "))
            .join(" · ")}
        </p>
      ) : null}
      {row.blockedReason ? (
        <p className="mt-1 text-xs text-amber-500/70">blocked: {row.blockedReason}</p>
      ) : null}
    </div>
  );
}

function WhyNowList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: ResurfacingWhyNowReviewRow[];
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
          rows.slice(0, 10).map((row) => <WhyNowRow key={row.noteId} row={row} />)
        )}
      </CardContent>
    </Card>
  );
}

export function ResurfacingWhyNowDebugPanel({
  report,
}: {
  report: ResurfacingWhyNowDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Candidates scored" value={String(report.totalCandidates)} />
          <Row label="With explanation" value={String(report.withExplanation.length)} />
          <Row label="Missing explanation" value={String(report.withoutExplanation.length)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Reason kinds</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {Object.entries(report.byKind).map(([kind, count]) => (
            <Row key={kind} label={kind.replace(/_/g, " ")} value={String(count)} />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Top explanations</CardTitle>
        </CardHeader>
        <CardContent>
          {report.topExplanations.length === 0 ? (
            <p className="text-sm text-zinc-500">No explanations yet.</p>
          ) : (
            report.topExplanations.map((item) => (
              <Row key={item.explanation} label={item.explanation} value={String(item.count)} />
            ))
          )}
        </CardContent>
      </Card>

      <WhyNowList
        title="Surfaced with explanation"
        rows={report.withExplanation}
        empty="No callbacks with why-now copy yet."
      />
      <WhyNowList
        title="Missing explanation"
        rows={report.withoutExplanation}
        empty="All candidates have explanations."
      />

      {report.blockedSamples.length > 0 ? (
        <WhyNowList
          title="Blocked copy samples"
          rows={report.blockedSamples}
          empty="No blocked samples."
        />
      ) : null}
    </div>
  );
}
