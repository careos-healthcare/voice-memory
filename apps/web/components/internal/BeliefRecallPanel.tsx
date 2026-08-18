"use client";

import type { BeliefRecallReport } from "@/types/belief-recall";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface BeliefRecallPanelProps {
  report: BeliefRecallReport;
}

export function BeliefRecallPanel({ report }: BeliefRecallPanelProps) {
  return (
    <Card className="border-amber-500/25 bg-zinc-900/50">
      <CardHeader>
        <CardTitle className="text-lg text-white">Belief recall (7 days)</CardTitle>
        <p className="text-sm font-medium text-amber-200/90">{report.criticalQuestion}</p>
      </CardHeader>
      <CardContent>
        <p className="text-sm leading-relaxed text-zinc-300">{report.criticalAnswer}</p>
        <p className="mt-3 text-xs text-zinc-500">
          Verdict: {report.verdict} · {report.totalResponses} responses
          {report.rememberedRate !== null ? ` · ${report.rememberedRate}% remembered` : ""}
        </p>
      </CardContent>
    </Card>
  );
}
