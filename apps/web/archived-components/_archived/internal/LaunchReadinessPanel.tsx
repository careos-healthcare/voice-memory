"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { LaunchReadinessReport } from "@/types/internal-archive";

const VERDICT_STYLES = {
  NOT_READY: "text-amber-300 border-amber-500/30 bg-amber-950/20",
  ALMOST_READY: "text-sky-300 border-sky-500/30 bg-sky-950/20",
  READY: "text-emerald-300 border-emerald-500/30 bg-emerald-950/20",
} as const;

type LaunchReadinessPanelProps = {
  report: LaunchReadinessReport;
};

export function LaunchReadinessPanel({ report }: LaunchReadinessPanelProps) {
  return (
    <div className="space-y-6" data-testid="launch-readiness-panel">
      <div
        className={`rounded-2xl border px-4 py-4 ${VERDICT_STYLES[report.verdict]}`}
        data-launch-verdict={report.verdict}
      >
        <p className="text-xs uppercase tracking-wide opacity-80">Launch verdict</p>
        <p className="mt-1 text-2xl font-semibold">{report.verdict.replace("_", " ")}</p>
      </div>

      <ul className="grid gap-4 sm:grid-cols-2">
        {[
          report.mobileReadiness,
          report.storeReadiness,
          report.distributionReadiness,
          report.revenueReadiness,
          report.activationReadiness,
        ].map((row) => (
          <li key={row.label}>
            <Card className="border-white/10 bg-zinc-900/50 h-full">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-zinc-200">{row.label}</CardTitle>
              </CardHeader>
              <CardContent>
                <p
                  className={`text-xs font-medium uppercase tracking-wide ${
                    row.ready ? "text-emerald-400" : "text-zinc-500"
                  }`}
                >
                  {row.ready ? "Ready" : "Not ready"}
                </p>
                <p className="mt-2 text-sm text-zinc-500">{row.detail}</p>
              </CardContent>
            </Card>
          </li>
        ))}
      </ul>
    </div>
  );
}
