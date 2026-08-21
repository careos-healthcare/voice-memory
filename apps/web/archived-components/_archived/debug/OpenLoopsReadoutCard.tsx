"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  openLoopHealthTone,
  type OpenLoopReadoutHealth,
  type OpenLoopReadoutMetric,
} from "@/lib/open-loops/open-loop-readout";

function toneClasses(tone: "neutral" | "warning" | "positive"): string {
  if (tone === "positive") return "text-emerald-300/90";
  if (tone === "warning") return "text-amber-200/80";
  return "text-zinc-300";
}

export function OpenLoopsReadoutMetricCard({ metric }: { metric: OpenLoopReadoutMetric }) {
  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-400">{metric.label}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        <p className="text-2xl font-normal tabular-nums tracking-tight text-zinc-200">
          {metric.value}
        </p>
        <p className="leading-relaxed text-zinc-500">{metric.plain}</p>
      </CardContent>
    </Card>
  );
}

export function OpenLoopsHealthBanner({
  health,
  headline,
}: {
  health: OpenLoopReadoutHealth;
  headline: string;
}) {
  const border =
    health === "strong"
      ? "border-emerald-500/25 bg-emerald-950/15"
      : health === "promising"
        ? "border-violet-500/20 bg-violet-950/10"
        : "border-amber-500/25 bg-amber-950/15";

  const label =
    health === "strong" ? "Strong" : health === "promising" ? "Promising" : "Weak";

  return (
    <Card className={border}>
      <CardContent className="py-5">
        <p className="text-xs uppercase tracking-[0.18em] text-zinc-500">Verdict</p>
        <p className={`mt-2 text-2xl font-normal ${toneClasses(openLoopHealthTone(health))}`}>
          {label}
        </p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">{headline}</p>
      </CardContent>
    </Card>
  );
}
