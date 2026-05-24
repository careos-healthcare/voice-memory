"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { RememberedLaterReport } from "@/types/social-proof";

export function RememberedLaterPanel({ report }: { report: RememberedLaterReport }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">Remembered later</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">72h remembered</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.remembered72hCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Quoted back</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.quotedBackCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Delayed revisit</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.delayedRevisitCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Delayed reflection</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.delayedReflectionCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Copied reopened</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.copiedReopenedCount}</p>
          </div>
        </div>

        {report.rows.length === 0 ? (
          <p className="text-sm text-zinc-500">No remembered-later signals yet.</p>
        ) : (
          <ul className="space-y-2">
            {report.rows.slice(0, 8).map((row) => (
              <li
                key={row.callbackId}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                <p className="mt-1 text-xs text-zinc-600">
                  {[
                    row.remembered72h ? "72h" : null,
                    row.quotedBack ? "quoted" : null,
                    row.delayedRevisit ? "revisit" : null,
                    row.delayedReflection ? "reflection" : null,
                    row.copiedReopened ? "copied reopen" : null,
                  ]
                    .filter(Boolean)
                    .join(" · ") || "low signal"}
                  {" · score "}
                  {row.score}
                </p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
