"use client";

import type { ReactNode } from "react";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { healthTone, type RetentionHealth, type RetentionReadoutMetric } from "@/lib/retention/retention-readout";

function toneClasses(tone: "neutral" | "warning" | "positive", failure?: boolean): string {
  if (failure) return "text-amber-200/90";
  if (tone === "positive") return "text-emerald-300/90";
  if (tone === "warning") return "text-amber-200/80";
  return "text-zinc-300";
}

export function RetentionReadoutCard({
  title,
  metric,
  health,
  children,
}: {
  title: string;
  metric?: RetentionReadoutMetric;
  health?: RetentionHealth;
  children?: ReactNode;
}) {
  const tone = health ? healthTone(health) : metric?.failure ? "warning" : "neutral";

  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-400">{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        {metric ? (
          <>
            <p className={`text-2xl font-normal tabular-nums tracking-tight ${toneClasses(tone, metric.failure)}`}>
              {metric.value}
            </p>
            <p className="leading-relaxed text-zinc-500">{metric.plain}</p>
          </>
        ) : null}
        {children}
      </CardContent>
    </Card>
  );
}

export function RetentionHealthBanner({
  health,
  headline,
}: {
  health: RetentionHealth;
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
        <p className="text-xs uppercase tracking-[0.18em] text-zinc-500">Retention health</p>
        <p className="mt-2 text-2xl font-normal text-zinc-100">{label}</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">{headline}</p>
      </CardContent>
    </Card>
  );
}

export function RetentionFailuresCard({
  lines,
  suppressedExamples,
  neverOpenedIds,
}: {
  lines: string[];
  suppressedExamples: string[];
  neverOpenedIds: string[];
}) {
  if (lines.length === 0 && suppressedExamples.length === 0 && neverOpenedIds.length === 0) {
    return null;
  }

  return (
    <Card className="border-amber-500/20 bg-amber-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-amber-200/90">Failures (read honestly)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 text-sm text-zinc-400">
        {lines.map((line) => (
          <p key={line} className="leading-relaxed text-amber-100/80">
            {line}
          </p>
        ))}
        {suppressedExamples.length > 0 ? (
          <div>
            <p className="text-xs text-zinc-600">Suppressed generic examples</p>
            <ul className="mt-2 list-inside list-disc space-y-1 text-zinc-500">
              {suppressedExamples.map((text) => (
                <li key={text}>{text}</li>
              ))}
            </ul>
          </div>
        ) : null}
        {neverOpenedIds.length > 0 ? (
          <div>
            <p className="text-xs text-zinc-600">Shown, never opened</p>
            <p className="mt-1 font-mono text-[11px] text-zinc-600">{neverOpenedIds.join(", ")}</p>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
