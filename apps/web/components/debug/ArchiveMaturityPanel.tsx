"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadArchiveMaturityJson } from "@/lib/debug/archive-maturity-review";
import type { ArchiveMaturityReport } from "@/types/memory-compounding";

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; text: string; detail?: string; score?: number }>;
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
                {row.score !== undefined ? (
                  <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">score {row.score}</p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function ArchiveMaturityPanel({ report }: { report: ArchiveMaturityReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Long-horizon archive maturity — compounding, durability, and revisit sequencing.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadArchiveMaturityJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Density</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.archiveDepth.densityScore}</p>
            <p className="mt-1 text-xs text-zinc-600">{report.archiveDepth.densityTrend}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Durable leaders</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.durableCallbacks.leaders.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Slow realizations</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.slowRealizations.candidates.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Revisit fatigue</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.revisitSequencing.revisitFatigueActive ? "Yes" : "No"}
            </p>
          </CardContent>
        </Card>
      </div>

      {report.revisitFatigueWarnings.length > 0 ? (
        <Card className="border-amber-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-amber-200/90">Revisit fatigue warnings</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.revisitFatigueWarnings.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Emotional durability leaders"
          rows={report.durableCallbacks.leaders.map((row) => ({
            id: row.id,
            text: row.text,
            score: row.durableScore,
            detail: `${row.revisits} revisits · ${row.copies} copies`,
          }))}
          empty="No durable callbacks yet."
        />
        <LineList
          title="Faded after novelty"
          rows={report.durableCallbacks.fadedAfterNovelty.map((row) => ({
            id: row.id,
            text: row.text,
            score: row.durableScore,
          }))}
          empty="No novelty fades flagged."
        />
        <LineList
          title="Slow realizations surfaced"
          rows={report.slowRealizations.candidates.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.gapDays}d gap · ${row.supportingCount} supporting`,
          }))}
          empty="No slow realizations eligible yet."
        />
        <LineList
          title="Compounding candidates"
          rows={report.compounding.candidates.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.kind} · ${row.gapDays}d`,
            score: row.strength,
          }))}
          empty="Archive too young for compounding."
        />
        <LineList
          title="Longitudinal emotional residue"
          rows={report.longitudinalResidueLeaders}
          empty="No residue leaders yet."
        />
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Month-over-month continuity</CardTitle>
          </CardHeader>
          <CardContent>
            {report.monthOverMonthContinuity.length === 0 ? (
              <p className="text-sm text-zinc-500">Not enough months yet.</p>
            ) : (
              <ul className="flex flex-wrap gap-3">
                {report.monthOverMonthContinuity.map((row) => (
                  <li key={row.month} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-400">
                    {row.month}: <span className="tabular-nums text-zinc-200">{row.score}</span>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
