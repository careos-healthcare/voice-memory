"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadDistributionReadinessJson } from "@/lib/debug/distribution-readiness";
import type { DistributionReadinessReport } from "@/types/sharing";

function ScoreCard({ label, value }: { label: string; value: number | string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
      </CardContent>
    </Card>
  );
}

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; text: string; detail?: string; score?: number; reason?: string }>;
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
              <li
                key={row.id}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                {row.reason ? <p className="mt-1 text-xs text-zinc-600">{row.reason}</p> : null}
                {row.detail ? <p className="mt-1 text-xs text-zinc-600">{row.detail}</p> : null}
                {row.score !== undefined ? (
                  <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                    score {row.score}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function DistributionReadinessPanel({
  report,
}: {
  report: DistributionReadinessReport;
}) {
  const obs = report.shareObservation;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Quiet distribution — grounded lines, cringe risk, and share observation.
        </p>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => downloadDistributionReadinessJson(report)}
        >
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <ScoreCard label="Emotional clarity" value={report.emotionalClarityScore} />
        <ScoreCard label="Creator preview done" value={`${report.creatorPreviewCompletionRate}%`} />
        <ScoreCard label="Invite → return" value={`${report.inviteReturnConversion}%`} />
        <ScoreCard label="Revisit after share" value={`${report.revisitAfterShareConversion}%`} />
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <ScoreCard label="Shared callbacks" value={obs.sharedCallbacksCount} />
        <ScoreCard label="Shared revisits" value={obs.sharedRevisitMomentsCount} />
        <ScoreCard label="Invite opens" value={obs.inviteOpensCount} />
        <ScoreCard label="Copied then shared" value={obs.copiedThenSharedCount} />
        <ScoreCard label="Preview completions" value={obs.creatorPreviewCompletionsCount} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Most shareable grounded lines"
          rows={report.mostShareableGroundedLines}
          empty="No grounded share lines scored yet."
        />
        <LineList
          title="Cringe-risk lines"
          rows={report.cringeRiskLines}
          empty="No cringe-risk lines flagged."
        />
        <LineList
          title="Copied-before-shared callbacks"
          rows={report.copiedBeforeSharedCallbacks.map((row) => ({
            id: row.id,
            text: row.text,
            detail: row.at,
          }))}
          empty="No copied-then-shared flows yet."
        />
        <LineList
          title="Recent shared callbacks"
          rows={obs.sharedCallbacks.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.source} · ${row.at.slice(0, 10)}`,
          }))}
          empty="No shared callbacks recorded."
        />
      </div>
    </div>
  );
}
