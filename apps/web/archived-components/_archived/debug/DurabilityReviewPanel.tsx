"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { DurabilityReviewReport } from "@/types/emotional-integrity-layer";

const CATEGORY_LABEL: Record<DurabilityReviewReport["rows"][number]["category"], string> = {
  maintenance: "Maintenance",
  sync: "Sync",
  migration: "Migration",
  dependency: "Dependency",
  lineage: "Lineage",
  corruption: "Corruption",
  continuity: "Continuity",
};

export function DurabilityReviewPanel({ report }: { report: DurabilityReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-3">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Maintenance hotspots
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.maintenanceHotspots}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Continuity risk
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.continuityRiskScore}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Findings
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.rows.length}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        {report.rows.map((row) => (
          <Card key={row.id}>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                {CATEGORY_LABEL[row.category]} · {row.severity}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm font-medium text-zinc-200">{row.label}</p>
              <p className="mt-1 text-xs leading-relaxed text-zinc-500">{row.detail}</p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
