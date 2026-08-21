"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { BlindSpotExperimentLoopReport } from "@/types/blind-spot-experiment-loop";

interface BlindSpotExperimentLoopPanelProps {
  report: BlindSpotExperimentLoopReport;
}

function rateLabel(value: number | null): string {
  if (value === null) return "—";
  return `${value}%`;
}

export function BlindSpotExperimentLoopPanel({ report }: BlindSpotExperimentLoopPanelProps) {
  return (
    <Card className="border-emerald-500/20 bg-emerald-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-base text-emerald-100">
          Pattern → experiment → follow-up
        </CardTitle>
        <p className="text-xs text-zinc-500">
          Commitment and seven-day follow-up — behavior-change measurement (local data only).
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-3 sm:grid-cols-3">
          <div>
            <p className="text-xs text-zinc-500">Commitment rate</p>
            <p className="text-xl font-semibold text-white">
              {rateLabel(report.commitmentRate)}
            </p>
            <p className="text-xs text-zinc-600">{report.commitmentCount} commitments</p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Follow-up completion</p>
            <p className="text-xl font-semibold text-white">
              {rateLabel(report.followUpCompletionRate)}
            </p>
            <p className="text-xs text-zinc-600">
              {report.followUpCompletedCount} answered · {report.dueFollowUpCount} pending
            </p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Caught it earlier</p>
            <p className="text-xl font-semibold text-white">
              {rateLabel(report.caughtEarlierRate)}
            </p>
            <p className="text-xs text-zinc-600">{report.caughtEarlierCount} early catches</p>
          </div>
        </div>

        <div className="space-y-2 border-t border-white/5 pt-3">
          <p className="text-xs uppercase tracking-wider text-zinc-500">By ingredient</p>
          {report.byIngredient.map((row) => (
            <p key={row.ingredient} className="text-sm text-zinc-400">
              <span className="text-zinc-200">{row.label}</span> — {row.commitments} committed ·{" "}
              {row.followUpsCompleted} follow-ups · caught earlier{" "}
              {rateLabel(row.caughtEarlierRate)}
            </p>
          ))}
        </div>

        <ul className="space-y-1 border-t border-white/5 pt-3 text-xs text-zinc-500">
          {report.lines.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
