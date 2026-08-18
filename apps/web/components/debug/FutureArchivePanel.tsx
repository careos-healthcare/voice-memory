"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadFutureArchiveJson } from "@/lib/debug/future-archive-review";
import type { FutureArchiveSimulationReport } from "@/types/archive-permanence-layer";

function HorizonCard({
  horizon,
}: {
  horizon: FutureArchiveSimulationReport["horizons"][number];
}) {
  return (
    <Card className={horizon.believable ? "border-emerald-900/20" : "border-amber-900/30"}>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{horizon.years} years later</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm text-zinc-400">
        <p>Archive density (projected): {horizon.projectedDensity}</p>
        <p>Callback durability: {horizon.callbackDurability}</p>
        <p>Revisit fatigue risk: {horizon.revisitFatigueRisk}</p>
        <p>Resurfacing repetition risk: {horizon.resurfacingRepetitionRisk}</p>
        <p>Landmark survival: {horizon.landmarkSurvival}</p>
        <p>Continuity drift: {horizon.continuityDrift}</p>
        <p className="text-xs text-zinc-600">
          {horizon.believable ? "Still emotionally believable" : "May feel thin or repetitive"}
        </p>
      </CardContent>
    </Card>
  );
}

export function FutureArchivePanel({ report }: { report: FutureArchiveSimulationReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Simulates whether the archive still feels calm and personally meaningful at 1, 3, and 5 years.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadFutureArchiveJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <Card>
        <CardHeader className="pb-1">
          <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
            Current span
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold tabular-nums text-white">{report.currentArchiveSpanDays}</p>
          <p className="mt-1 text-xs text-zinc-600">days of archive history</p>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-3">
        {report.horizons.map((horizon) => (
          <HorizonCard key={horizon.years} horizon={horizon} />
        ))}
      </div>
    </div>
  );
}
