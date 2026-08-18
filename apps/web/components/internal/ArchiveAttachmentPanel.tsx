"use client";

import type { ArchiveAttachmentReport } from "@/types/archive-attachment";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface ArchiveAttachmentPanelProps {
  report: ArchiveAttachmentReport;
}

function verdictColor(verdict: ArchiveAttachmentReport["verdict"]): string {
  switch (verdict) {
    case "strong":
      return "text-emerald-300";
    case "weak":
      return "text-amber-300";
    case "mixed":
      return "text-violet-300";
    default:
      return "text-zinc-500";
  }
}

export function ArchiveAttachmentPanel({ report }: ArchiveAttachmentPanelProps) {
  return (
    <div className="space-y-6">
      <Card className="border-rose-500/25 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Critical output</CardTitle>
          <p className="text-sm font-medium text-rose-200/90">{report.criticalQuestion}</p>
        </CardHeader>
        <CardContent>
          <p className="text-sm leading-relaxed text-zinc-300">{report.criticalAnswer}</p>
          <p className={`mt-3 text-xs uppercase tracking-wider ${verdictColor(report.verdict)}`}>
            Verdict: {report.verdict}
            {report.strongAttachmentPercent !== null
              ? ` · ${report.strongAttachmentPercent}% Very/Extremely (strong ≥50%, weak <20%)`
              : ""}
          </p>
          <p className="mt-2 text-xs text-zinc-500">
            {report.totalResponses} responses on this device
            {report.averageAttachmentScore !== null
              ? ` · avg score ${report.averageAttachmentScore}/4`
              : ""}
          </p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Archive attachment</CardTitle>
          <p className="text-sm text-zinc-400">
            Disappointment if the archive disappeared — correlated with return, subscription,
            and breakthrough (device-local).
          </p>
        </CardHeader>
        <CardContent className="space-y-6 text-sm">
          {report.distribution.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Distribution</p>
              <ul className="mt-2 space-y-1 text-zinc-400">
                {report.distribution.map((row) => (
                  <li key={row.level}>
                    {row.label}: {row.count} ({row.sharePercent}%)
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.byLevelOutcomes.length > 0 ? (
            <div className="overflow-x-auto">
              <p className="mb-2 text-xs uppercase tracking-wider text-zinc-500">
                Attachment vs outcomes
              </p>
              <table className="w-full min-w-[520px] text-left text-xs">
                <thead>
                  <tr className="border-b border-zinc-800 text-zinc-500">
                    <th className="py-2 pr-3 font-normal">Level</th>
                    <th className="py-2 pr-3 font-normal">n</th>
                    <th className="py-2 pr-3 font-normal">7d return</th>
                    <th className="py-2 pr-3 font-normal">Subscribe</th>
                    <th className="py-2 pr-3 font-normal">Breakthrough</th>
                  </tr>
                </thead>
                <tbody>
                  {report.byLevelOutcomes.map((row) => (
                    <tr key={row.level} className="border-b border-zinc-800/60 text-zinc-300">
                      <td className="py-2 pr-3">{row.label}</td>
                      <td className="py-2 pr-3 tabular-nums">{row.count}</td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.returnRate ?? "—"}
                        {row.returnRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.subscriptionRate ?? "—"}
                        {row.subscriptionRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.breakthroughRate ?? "—"}
                        {row.breakthroughRate !== null ? "%" : ""}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}

          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">Attachment vs archive age</p>
            <p className="mt-2 text-zinc-400">{report.archiveAgeSummary}</p>
          </div>

          {report.topAttachmentReasons.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Top attachment reasons</p>
              <ul className="mt-2 space-y-1 text-zinc-400">
                {report.topAttachmentReasons.map((row) => (
                  <li key={row.reason}>
                    {row.label}: {row.count} ({row.sharePercent}%)
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
