"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  RevisitQualityDebugReport,
  RevisitQualityReviewRow,
} from "@/types/revisit-quality";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function RevisitRow({ row }: { row: RevisitQualityReviewRow }) {
  return (
    <div className="border-b border-white/5 py-2 text-sm">
      <p className="text-zinc-300">{row.text}</p>
      <p className="mt-1 text-xs text-zinc-500">
        {row.classification.replace(/_/g, " ")} · score {row.total}
        {row.protected ? " · protected" : ""}
        {row.suppressed ? " · suppressed" : ""}
      </p>
      <p className="mt-1 text-xs text-zinc-600">
        {row.flags.length > 0 ? row.flags.join(" · ") : "no flags"}
      </p>
    </div>
  );
}

export function RevisitQualityDebugPanel({ report }: { report: RevisitQualityDebugReport }) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Candidates scored" value={String(report.totalCandidates)} />
          <Row label="Weak revisits" value={String(report.byClassification.weak_revisit)} />
          <Row label="Informational revisits" value={String(report.byClassification.informational_revisit)} />
          <Row label="Meaningful revisits" value={String(report.byClassification.meaningful_revisit)} />
          <Row label="Durable revisits" value={String(report.byClassification.durable_revisit)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Revisit → reflection quality</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Revisits logged" value={String(report.reflectionQuality.revisitCount)} />
          <Row label="Reflections after revisit" value={String(report.reflectionQuality.reflectionAfterCount)} />
          <Row label="Conversion" value={report.reflectionQuality.conversionRate} />
          <Row label="Meaningful / durable" value={`${report.reflectionQuality.meaningfulCount} / ${report.reflectionQuality.durableCount}`} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Revisit fatigue risk</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Fatigue active" value={report.fatigueRisk.active ? "Yes" : "No"} />
          <Row label="Recent revisits (7d)" value={String(report.fatigueRisk.recentRevisits)} />
          <Row label="Weak revisit ratio" value={`${report.fatigueRisk.weakRevisitRatio}%`} />
          <p className="mt-2 text-xs leading-relaxed text-zinc-500">{report.fatigueRisk.recommendation}</p>
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Best revisits</CardTitle>
        </CardHeader>
        <CardContent>
          {report.bestRevisits.length === 0 ? (
            <p className="text-sm text-zinc-500">No strong revisit lines yet.</p>
          ) : (
            report.bestRevisits.map((row) => <RevisitRow key={row.noteId} row={row} />)
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Worst revisits</CardTitle>
        </CardHeader>
        <CardContent>
          {report.worstRevisits.length === 0 ? (
            <p className="text-sm text-zinc-500">None flagged yet.</p>
          ) : (
            report.worstRevisits.map((row) => <RevisitRow key={`worst-${row.noteId}`} row={row} />)
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Generic revisit copy</CardTitle>
        </CardHeader>
        <CardContent>
          {report.genericCopy.length === 0 ? (
            <p className="text-sm text-zinc-500">None flagged.</p>
          ) : (
            report.genericCopy.map((row) => <RevisitRow key={`generic-${row.noteId}`} row={row} />)
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overclaimed revisit copy</CardTitle>
        </CardHeader>
        <CardContent>
          {report.overclaimedCopy.length === 0 ? (
            <p className="text-sm text-zinc-500">None flagged.</p>
          ) : (
            report.overclaimedCopy.map((row) => <RevisitRow key={`over-${row.noteId}`} row={row} />)
          )}
        </CardContent>
      </Card>
    </div>
  );
}
