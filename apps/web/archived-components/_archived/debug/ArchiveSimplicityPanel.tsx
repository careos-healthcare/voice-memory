"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ArchiveSimplicityReport } from "@/types/emotional-integrity-layer";

const CATEGORY_LABEL: Record<ArchiveSimplicityReport["rows"][number]["category"], string> = {
  overlap: "Overlap",
  duplicate: "Duplicate",
  unused: "Unused",
  hotspot: "Hotspot",
  redundant_surface: "Redundant surface",
};

export function ArchiveSimplicityPanel({ report }: { report: ArchiveSimplicityReport }) {
  return (
    <div className="space-y-6">
      {report.overdesigned ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
          The archive may be becoming overdesigned.
        </div>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">{report.removalQuestion}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-500">
            Overlap score {report.overlapScore} · {report.rows.length} findings
          </p>
        </CardContent>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        {report.rows.map((row) => (
          <Card key={row.id}>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                {CATEGORY_LABEL[row.category]}
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
