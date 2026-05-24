"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { ProductionReadinessReport, ReadinessCheck } from "@/types/observation-workflow";

function statusColor(status: ReadinessCheck["status"]): string {
  switch (status) {
    case "pass":
      return "text-emerald-300/90";
    case "fail":
      return "text-red-300/90";
    case "warn":
      return "text-amber-200/90";
    default:
      return "text-zinc-400";
  }
}

export function ProductionReadinessPanel({ report }: { report: ProductionReadinessReport }) {
  return (
    <div className="space-y-6">
      <Card className={report.ready ? "border-emerald-900/40" : "border-amber-900/40"}>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">
            {report.ready ? "No blocking failures" : "Blocking or missing checks"}
          </CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          {report.passed} passed · {report.warnings} warnings · {report.failed} failed
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">Device checklist</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-3">
            {report.checks.map((row) => (
              <li key={row.id} className="rounded-xl bg-white/[0.03] px-3 py-3">
                <p className={`text-sm ${statusColor(row.status)}`}>
                  {row.label} — {row.status}
                </p>
                <p className="mt-1 text-xs text-zinc-500">{row.detail}</p>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
