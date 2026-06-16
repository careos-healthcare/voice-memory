"use client";

import type { RetentionMoatReport } from "@/lib/internal/retention-moat-report";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface RetentionMoatPanelProps {
  report: RetentionMoatReport;
}

export function RetentionMoatPanel({ report }: RetentionMoatPanelProps) {
  return (
    <Card className="border-violet-500/20 bg-zinc-900/50">
      <CardHeader>
        <CardTitle className="text-lg text-white">Competitor-lesson retention moat</CardTitle>
        <p className="text-sm text-zinc-400">{report.mainQuestion}</p>
      </CardHeader>
      <CardContent className="space-y-4 text-sm text-zinc-300">
        <div className="grid gap-3 sm:grid-cols-2">
          <Metric label="Movement summary seen" value={report.movementSummarySeen} />
          <Metric label="Movement summary expanded" value={report.movementSummaryExpanded} />
          <Metric label="Archive maturity seen" value={report.archiveMaturitySeen} />
          <Metric label="Archive maturity clicked" value={report.archiveMaturityClicked} />
          <Metric
            label="Maturity on device"
            value={`${report.archiveMaturityStage} · ${report.archiveMaturityPercent}%`}
          />
          <Metric label="Archive asset card seen" value={report.archiveAssetSeen} />
          <Metric label="Hard-to-reproduce seen" value={report.hardToReproduceSeen} />
          <Metric label="Hard-to-reproduce expanded" value={report.hardToReproduceExpanded} />
          <Metric label="Discover opened" value={report.discoverOpened} />
          <Metric label="Archive belief viewed" value={report.archiveBeliefViewed} />
          <Metric label="Returned to check archive" value={report.returnedToCheckArchive} />
        </div>
        {report.livingSystemSignals.length > 0 ? (
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">Living-system signals</p>
            <ul className="mt-2 list-inside list-disc text-zinc-400">
              {report.livingSystemSignals.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ul>
          </div>
        ) : (
          <p className="text-zinc-500">No strong living-system signals on this device yet.</p>
        )}
      </CardContent>
    </Card>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-zinc-800 bg-zinc-950/60 px-3 py-2">
      <p className="text-xs text-zinc-500">{label}</p>
      <p className="mt-1 font-medium tabular-nums text-zinc-200">{value}</p>
    </div>
  );
}
