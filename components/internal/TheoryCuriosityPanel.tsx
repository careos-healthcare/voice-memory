"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildTheoryCuriosityReport } from "@/lib/metrics/theory-curiosity";
import type { TheoryCuriosityReport } from "@/types/personal-theory";

interface TheoryCuriosityPanelProps {
  report: TheoryCuriosityReport;
}

export function TheoryCuriosityPanel({ report }: TheoryCuriosityPanelProps) {
  return (
    <Card className="border-white/10 bg-black/30">
      <CardHeader>
        <CardTitle className="text-lg text-white">Theory Curiosity Rate</CardTitle>
        <p className="text-sm text-zinc-500">
          Before opening ArchiveMe — were users curious whether the archive had changed its view?
        </p>
      </CardHeader>
      <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Metric label="Curiosity rate" value={`${report.theoryCuriosityRate}%`} />
        <Metric label="Responses" value={String(report.totalResponses)} />
        <Metric label="Yes" value={String(report.yesCount)} />
        <Metric label="Maybe / No" value={`${report.maybeCount} / ${report.noCount}`} />
      </CardContent>
    </Card>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-white/5 bg-white/[0.02] px-3 py-3">
      <p className="text-[10px] uppercase tracking-wider text-zinc-600">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums text-zinc-100">{value}</p>
    </div>
  );
}
