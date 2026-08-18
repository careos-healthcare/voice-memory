"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MoatReviewReport } from "@/types/observation-workflow";

export function MoatReviewScoreboard({ report }: { report: MoatReviewReport }) {
  return (
    <div className="space-y-6">
      <Card className="border-violet-400/20 bg-violet-500/5">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Exact behavior scoreboard</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          {report.metCount} of {report.totalCount} targets met
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">Current vs target</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-3">
            {report.metrics.map((row) => (
              <li
                key={row.id}
                className="flex flex-wrap items-baseline justify-between gap-3 rounded-xl bg-white/[0.03] px-3 py-3"
              >
                <div>
                  <p className="text-sm text-zinc-200">{row.label}</p>
                  {row.countHint ? (
                    <p className="mt-1 text-xs text-zinc-600">{row.countHint}</p>
                  ) : null}
                </div>
                <div className="text-right text-sm tabular-nums">
                  <span className={row.met ? "text-emerald-300/90" : "text-amber-200/90"}>
                    {row.current}
                  </span>
                  {row.targetValue > 0 ? (
                    <>
                      <span className="mx-2 text-zinc-600">→</span>
                      <span className="text-zinc-500">{row.target}</span>
                    </>
                  ) : null}
                </div>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
