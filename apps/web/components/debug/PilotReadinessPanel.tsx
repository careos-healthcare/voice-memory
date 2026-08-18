"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { PilotReadinessReport } from "@/types/pilot-system";

export function PilotReadinessPanel({ report }: { report: PilotReadinessReport }) {
  return (
    <div className="space-y-6">
      {report.observeMessage ? (
        <Card className="border-amber-900/30">
          <CardContent className="py-4 text-sm text-amber-200/90">{report.observeMessage}</CardContent>
        </Card>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Ready to charge</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.ready ? "Yes" : "Not yet"}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Payment readiness confidence
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.paymentReadinessConfidence}</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Readiness checks</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 text-sm text-zinc-400">
            {report.checks.map((check) => (
              <li key={check.id}>
                {check.ok ? "✓" : "○"} {check.label} — {check.detail}
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
