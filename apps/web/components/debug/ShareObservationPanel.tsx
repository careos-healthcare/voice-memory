"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { ShareObservationReport } from "@/types/sharing";

export function ShareObservationPanel({ report }: { report: ShareObservationReport }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">Quiet sharing</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Shared callbacks</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.sharedCallbacksCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Shared revisits</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.sharedRevisitMomentsCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Invite opens</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.inviteOpensCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Preview done</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.creatorPreviewCompletionsCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Revisit after share</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.revisitAfterShareCount}</p>
          </div>
          <div className="rounded-lg bg-white/[0.03] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Copied then shared</p>
            <p className="mt-1 text-xl tabular-nums text-white">{report.copiedThenSharedCount}</p>
          </div>
        </div>

        {report.sharedCallbacks.length === 0 ? (
          <p className="text-sm text-zinc-500">No quiet shares recorded yet.</p>
        ) : (
          <ul className="space-y-2">
            {report.sharedCallbacks.slice(0, 6).map((row) => (
              <li
                key={`${row.id}-${row.at}`}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                <p className="mt-1 text-xs text-zinc-600">
                  {row.source} · {row.at.slice(0, 10)}
                </p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
