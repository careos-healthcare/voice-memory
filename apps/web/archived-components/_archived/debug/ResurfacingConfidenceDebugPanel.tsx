"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  ResurfacingConfidenceDebugReport,
  ResurfacingConfidenceReviewRow,
} from "@/types/resurfacing-confidence";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function ConfidenceRow({ row }: { row: ResurfacingConfidenceReviewRow }) {
  return (
    <div className="border-b border-white/5 py-2 text-sm">
      <p className="text-zinc-300">{row.text}</p>
      <p className="mt-1 text-xs text-zinc-500">
        {row.classification.replace(/_/g, " ")} · internal {row.totalConfidence}
      </p>
      {row.evidenceReason ? (
        <p className="mt-1 text-xs text-violet-300/80">{row.evidenceReason}</p>
      ) : null}
      <p className="mt-1 text-xs text-zinc-600">
        {row.reasons.length > 0 ? row.reasons.join(" · ") : "no evidence signals"}
      </p>
      {row.suppressReasons.length > 0 ? (
        <p className="mt-1 text-xs text-amber-500/80">
          suppressed: {row.suppressReasons.join(" · ")}
        </p>
      ) : null}
      {row.falsePositiveRisks.length > 0 ? (
        <p className="mt-1 text-xs text-zinc-600">
          risks: {row.falsePositiveRisks.join(" · ")}
        </p>
      ) : null}
    </div>
  );
}

function ConfidenceList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: ResurfacingConfidenceReviewRow[];
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
          rows.slice(0, 10).map((row) => <ConfidenceRow key={row.noteId} row={row} />)
        )}
      </CardContent>
    </Card>
  );
}

export function ResurfacingConfidenceDebugPanel({
  report,
}: {
  report: ResurfacingConfidenceDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Candidates scored" value={String(report.totalCandidates)} />
          <Row label="Suppressed" value={String(report.byClassification.suppress)} />
          <Row label="Weak" value={String(report.byClassification.weak)} />
          <Row label="Plausible" value={String(report.byClassification.plausible)} />
          <Row label="Strong" value={String(report.byClassification.strong)} />
          <Row label="Magic candidates" value={String(report.byClassification.magic_candidate)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Top evidence reasons</CardTitle>
        </CardHeader>
        <CardContent>
          {report.topEvidenceReasons.length === 0 ? (
            <p className="text-sm text-zinc-500">No surfaced evidence lines yet.</p>
          ) : (
            report.topEvidenceReasons.map((item) => (
              <Row key={item.reason} label={item.reason} value={String(item.count)} />
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">False-positive risks</CardTitle>
        </CardHeader>
        <CardContent>
          {report.falsePositiveRisks.length === 0 ? (
            <p className="text-sm text-zinc-500">No risk patterns flagged.</p>
          ) : (
            report.falsePositiveRisks.map((item) => (
              <Row key={item.risk} label={item.risk.replace(/_/g, " ")} value={String(item.count)} />
            ))
          )}
        </CardContent>
      </Card>

      <ConfidenceList
        title="Magic candidates"
        rows={report.magicCandidates}
        empty="No magic candidates yet."
      />
      <ConfidenceList title="Strong callbacks" rows={report.strong} empty="No strong callbacks yet." />
      <ConfidenceList title="Weak callbacks" rows={report.weak} empty="No weak callbacks in range." />
      <ConfidenceList
        title="Suppressed callbacks"
        rows={report.suppressed}
        empty="Nothing suppressed."
      />

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">
            Ignored / dismissed penalty effects
          </CardTitle>
        </CardHeader>
        <CardContent>
          {report.interactionPenaltySamples.length === 0 ? (
            <p className="text-sm text-zinc-500">No interaction penalties recorded.</p>
          ) : (
            report.interactionPenaltySamples.map((row) => (
              <ConfidenceRow key={`penalty-${row.noteId}`} row={row} />
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
