"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadArchivePermanenceReviewJson } from "@/lib/debug/archive-permanence-review";
import type { ArchivePermanenceReviewReport } from "@/types/archive-permanence-layer";

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; text: string; detail?: string }>;
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
          <ul className="space-y-2">
            {rows.map((row) => (
              <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300">
                <p>{row.text}</p>
                {row.detail ? <p className="mt-1 text-xs text-zinc-600">{row.detail}</p> : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function ArchivePermanencePanel({ report }: { report: ArchivePermanenceReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Founder permanence review — durable callbacks, continuity, migration, and landmarks.
        </p>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => downloadArchivePermanenceReviewJson(report)}
        >
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Permanent callbacks
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.permanentCallbacks.permanent.length}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Continuity risks
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.continuityBreakRisks.length}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Landmarks
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.landmarks.landmarks.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Export longevity
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.guarantees.exportLongevityScore}
            </p>
          </CardContent>
        </Card>
      </div>

      {report.weakFutureContinuity.length > 0 ? (
        <Card className="border-amber-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-amber-200/90">Weak future continuity</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.weakFutureContinuity.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Permanent callbacks"
          rows={report.permanentCallbacks.permanent.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.monthsSpan} months · ${row.revisits} revisits`,
          }))}
          empty="No permanent callbacks detected yet."
        />
        <LineList
          title="Archive landmarks"
          rows={report.landmarks.landmarks.map((row) => ({
            id: row.id,
            text: row.text,
            detail: row.evidence,
          }))}
          empty="No landmarks eligible yet."
        />
        <LineList
          title="Life periods"
          rows={report.lifePeriods.periods.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.startAt.slice(0, 10)} → ${row.endAt.slice(0, 10)}`,
          }))}
          empty="No life periods detected."
        />
        <LineList
          title="Migration risks"
          rows={report.migrationRisks.map((row, index) => ({
            id: `${row.level}-${index}`,
            text: row.message,
            detail: row.level,
          }))}
          empty="No migration issues."
        />
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Continuity integrity checks</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 text-sm text-zinc-400">
            {report.futureContinuity.checks.map((check) => (
              <li key={check.id}>
                {check.ok ? "✓" : "⚠"} {check.label} — {check.detail}
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
