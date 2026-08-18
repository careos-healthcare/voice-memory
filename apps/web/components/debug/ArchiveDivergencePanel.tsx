"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { ArchiveDivergenceReviewReport } from "@/types/archive-individuality";

const CATEGORY_LABEL: Record<ArchiveDivergenceReviewReport["rows"][number]["category"], string> = {
  similar_archives: "Similar archives",
  overused_family: "Overused family",
  spreading_structure: "Spreading structure",
  default_phrase: "Default phrase",
};

export function ArchiveDivergencePanel({ report }: { report: ArchiveDivergenceReviewReport }) {
  return (
    <div className="space-y-6">
      {report.founderWarnings.length > 0 ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3">
          <p className="text-xs uppercase tracking-wider text-amber-300/80">Founder warnings</p>
          <ul className="mt-2 space-y-1 text-sm text-amber-100">
            {report.founderWarnings.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">{report.divergenceQuestion}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-500">
            Homogenization score {report.homogenizationScore} · {report.rows.length} findings
          </p>
          {report.suggestions.length > 0 ? (
            <ul className="mt-3 space-y-1 text-sm text-zinc-400">
              {report.suggestions.map((line) => (
                <li key={line}>· {line}</li>
              ))}
            </ul>
          ) : null}
        </CardContent>
      </Card>

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
