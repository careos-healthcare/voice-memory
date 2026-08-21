"use client";

import { useMemo, useState } from "react";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  buildFounderArchiveDashboard,
  FOUNDER_DASHBOARD_TAB_COUNT,
} from "@/lib/internal/founder-archive-dashboard";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";
import { cn } from "@/lib/utils";
import type { FounderDashboardTabId } from "@/types/founder-focus";

export function FounderArchiveDashboard() {
  const view = useMemo(() => buildFounderArchiveDashboard(), []);
  const northStar = useMemo(() => buildNorthStarDashboard(), []);
  const [tab, setTab] = useState<FounderDashboardTabId>("activation");
  const active = view.tabs.find((t) => t.id === tab) ?? view.tabs[0]!;
  const tabMetrics = northStar.metrics.filter((m) => active.metricIds.includes(m.id));

  return (
    <div data-testid="founder-archive-dashboard" data-founder-tab-count={FOUNDER_DASHBOARD_TAB_COUNT}>
      <div
        className="flex gap-1 rounded-xl border border-white/10 bg-black/30 p-1"
        role="tablist"
        aria-label="Founder dashboard tabs"
      >
        {view.tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            aria-selected={tab === t.id}
            data-testid={`founder-tab-${t.id}`}
            className={cn(
              "flex-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
              tab === t.id
                ? "bg-violet-500/25 text-violet-100"
                : "text-zinc-500 hover:text-zinc-300",
            )}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="mt-6 space-y-4" role="tabpanel">
        <h2 className="text-lg font-medium text-zinc-200">{active.headline}</h2>
        <ul className="space-y-2 text-sm text-zinc-400">
          {active.bullets.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
        <div className="grid gap-4 sm:grid-cols-2">
          {tabMetrics.map((metric) => (
            <Card
              key={metric.id}
              className="border-white/10 bg-zinc-900/50"
              data-testid={`founder-tab-metric-${metric.id}`}
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
      </div>
    </div>
  );
}
