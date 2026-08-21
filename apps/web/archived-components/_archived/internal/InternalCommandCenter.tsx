"use client";

import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { buildFounderFocusScore } from "@/lib/internal/founder-focus-score";
import {
  INTERNAL_COMMAND_CENTER_ROUTE,
  INTERNAL_COMMAND_PILLARS,
  INTERNAL_LAUNCH_ROUTE,
} from "@/lib/internal/internal-archive-registry";
import { internalSurfaceReductionRatio } from "@/lib/internal/internal-archive-registry";

export function InternalCommandCenter() {
  const focus = buildFounderFocusScore();
  const reduction = Math.round(internalSurfaceReductionRatio() * 100);

  return (
    <div className="space-y-8" data-testid="internal-command-center">
      <div className="rounded-2xl border border-violet-500/30 bg-violet-950/20 px-4 py-4">
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder focus</p>
        <p className="mt-2 text-3xl font-semibold tabular-nums text-white">{focus.score}</p>
        <p className="mt-1 text-sm text-zinc-400">
          Target {focus.target}+ · {reduction}% internal surface archived ·{" "}
          {focus.discoverableRoutes} discoverable routes
        </p>
        <p className="mt-2 text-sm text-zinc-500">{focus.summary}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {INTERNAL_COMMAND_PILLARS.map((pillar) => (
          <Link key={pillar.id} href={pillar.route} className="block">
            <Card className="h-full border-white/10 bg-zinc-900/50 transition-colors hover:border-violet-500/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-lg text-zinc-100">{pillar.label}</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm font-medium text-zinc-400">{pillar.decisionQuestion}</p>
                <p className="mt-2 text-xs leading-relaxed text-zinc-600">
                  {pillar.decisionAction}
                </p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      <Link href={INTERNAL_LAUNCH_ROUTE} className="block">
        <Card className="border-emerald-500/25 bg-emerald-950/15 hover:border-emerald-500/40">
          <CardHeader>
            <CardTitle className="text-lg text-emerald-100/90">Launch readiness</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-zinc-400">
              Mobile, store, distribution, revenue, and activation — one verdict.
            </p>
          </CardContent>
        </Card>
      </Link>

      <p className="text-xs text-zinc-600">
        Start at {INTERNAL_COMMAND_CENTER_ROUTE}. Archived dashboards stay reachable by direct URL
        only.
      </p>
    </div>
  );
}
