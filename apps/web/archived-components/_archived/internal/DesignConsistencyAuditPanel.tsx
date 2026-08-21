"use client";

import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import type { DesignConsistencyFileReport } from "@/lib/internal/design-consistency-file-audit";

type DesignConsistencyAuditPanelProps = {
  report: DesignConsistencyFileReport;
};

export function DesignConsistencyAuditPanel({ report }: DesignConsistencyAuditPanelProps) {
  const { score, scanPatterns, failures } = report;
  const overall = score.passesTarget ? "CONSISTENT" : "INCONSISTENT";

  return (
    <Card className="border-sky-500/20 bg-sky-950/10" data-testid="design-consistency-audit-panel">
      <CardContent className="space-y-4 pt-6">
        <p className="text-sm font-medium text-sky-100">Design consistency audit v2</p>
        <p className="text-sm text-zinc-400">
          Archive surfaces should read as one product — shared hierarchy, spacing, typography,
          and CTA placement.
        </p>

        <div className="flex flex-wrap gap-3 text-xs">
          <span className={overall === "CONSISTENT" ? "text-emerald-300" : "text-amber-300"}>
            Overall: {overall} ({score.total}/{score.target})
          </span>
          <span className="text-zinc-500">Typography {score.typography}</span>
          <span className="text-zinc-500">Spacing {score.spacing}</span>
          <span className="text-zinc-500">Hierarchy {score.hierarchy}</span>
          <span className="text-zinc-500">CTA {score.cta}</span>
          <span className="text-zinc-500">Weight {score.visualWeight}</span>
          <span className="text-zinc-500">Mobile {score.mobile}</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-zinc-400">
            <thead>
              <tr className="border-b border-white/10 text-zinc-500">
                <th className="py-2 pr-3">Surface</th>
                <th className="py-2 pr-3">Verdict</th>
                <th className="py-2 pr-3">First visible</th>
                <th className="py-2 pr-3">Largest heading</th>
                <th className="py-2 pr-3">Primary CTA</th>
                <th className="py-2">Section order</th>
              </tr>
            </thead>
            <tbody>
              {scanPatterns.map((row) => (
                <tr key={row.surface} className="border-b border-white/5">
                  <td className="py-2 pr-3 capitalize text-zinc-300">{row.surface.replace("_", " ")}</td>
                  <td
                    className={`py-2 pr-3 ${row.verdict === "CONSISTENT" ? "text-emerald-300" : "text-amber-300"}`}
                  >
                    {row.verdict}
                  </td>
                  <td className="py-2 pr-3">{row.firstVisible}</td>
                  <td className="py-2 pr-3">{row.largestHeading}</td>
                  <td className="py-2 pr-3">{row.primaryCta ?? "—"}</td>
                  <td className="py-2">{row.sectionOrder.join(" → ") || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {failures.length > 0 ? (
          <ul className="list-inside list-disc space-y-1 text-xs text-amber-200/90">
            {failures.slice(0, 12).map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        ) : (
          <p className="text-xs text-emerald-300/90">All archive surfaces pass design consistency v2.</p>
        )}
      </CardContent>
    </Card>
  );
}
