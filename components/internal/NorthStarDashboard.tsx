"use client";

import { useMemo } from "react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";
import type { NorthStarDashboardView } from "@/types/founder-focus";

type NorthStarDashboardProps = {
  initial?: NorthStarDashboardView;
};

export function NorthStarDashboard({ initial }: NorthStarDashboardProps) {
  const view = useMemo(() => initial ?? buildNorthStarDashboard(), [initial]);

  return (
    <div className="grid gap-4 sm:grid-cols-2" data-testid="north-star-dashboard">
      {view.metrics.map((metric) => (
        <Card
          key={metric.id}
          className="border-white/10 bg-zinc-900/50"
          data-testid={`north-star-metric-${metric.id}`}
        >
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">{metric.title}</CardTitle>
            <p className="text-xs text-zinc-500">{metric.subtitle}</p>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold text-white">{metric.value}</p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-500">{metric.detail}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
