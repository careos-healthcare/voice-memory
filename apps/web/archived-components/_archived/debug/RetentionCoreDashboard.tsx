"use client";

import type { ReactNode } from "react";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  formatRetentionCoreBoolean,
  formatRetentionCoreDuration,
  formatRetentionCoreRate,
  type RetentionCoreMetricsReport,
} from "@/lib/debug/retention-core-metrics";

function MetricRow({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2.5 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <span className="text-xs text-zinc-500">{label}</span>
        {hint ? <p className="mt-0.5 text-[11px] leading-relaxed text-zinc-600">{hint}</p> : null}
      </div>
      <span className="text-sm tabular-nums text-zinc-200 sm:text-right">{value}</span>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent className="text-sm">{children}</CardContent>
    </Card>
  );
}

export function RetentionCoreDashboard({ report }: { report: RetentionCoreMetricsReport }) {
  const { magic, resurfacing, recurrence, funnel } = report;

  return (
    <div className="space-y-4">
      <Card className="border-amber-500/20 bg-amber-950/10">
        <CardContent className="py-4 text-sm leading-relaxed text-zinc-400">
          {report.scopeNote} Generated {report.generatedAt.slice(0, 16)}.
        </CardContent>
      </Card>

      <Section title="Magic moment">
        <MetricRow
          label="Time to first magic"
          value={formatRetentionCoreDuration(magic.timeToFirstMagicMs)}
          hint="First reflection → magic confirmed, or first magic candidate shown."
        />
        <MetricRow
          label="Reached magic on this device"
          value={formatRetentionCoreRate(magic.percentReachingMagic)}
          hint="Single-device cohort — 100% or 0%."
        />
        <MetricRow
          label="Magic confirmed at"
          value={magic.firstMagicConfirmedAt?.slice(0, 16) ?? "—"}
        />
        <MetricRow
          label="D1 return after first magic"
          value={formatRetentionCoreBoolean(magic.d1ReturnAfterMagic)}
          hint="Return event 1h–24h after magic anchor."
        />
        <MetricRow
          label="D7 return after first magic"
          value={formatRetentionCoreBoolean(magic.d7ReturnAfterMagic)}
          hint="Return event 1h–7d after magic anchor."
        />
      </Section>

      <Section title="Resurfacing quality & behavior">
        <MetricRow
          label="Average resurfacing confidence"
          value={
            resurfacing.averageConfidence === null
              ? "—"
              : `${resurfacing.averageConfidence}/100`
          }
          hint="Current candidate archive — not historical show-time scores."
        />
        <MetricRow
          label="Resurfacing open rate"
          value={formatRetentionCoreRate(resurfacing.openRate)}
          hint={`${resurfacing.callbacksOpened} opens / ${resurfacing.callbacksShown} shown events.`}
        />
        <MetricRow
          label="Resurfacing reread rate"
          value={formatRetentionCoreRate(resurfacing.rereadRate)}
          hint={`${resurfacing.callbacksReread} rereads after open.`}
        />
        <MetricRow
          label="Reflection after callback rate"
          value={formatRetentionCoreRate(resurfacing.reflectionAfterCallbackRate)}
          hint={`${resurfacing.reflectionAfterCallback} follow-up recordings after open.`}
        />
        <MetricRow
          label="Callback suppression rate"
          value={formatRetentionCoreRate(resurfacing.suppressionRate)}
          hint="Confidence scorer would suppress — among current candidates."
        />
        <MetricRow
          label="Weak callback exposure rate"
          value={formatRetentionCoreRate(resurfacing.weakCallbackExposureRate)}
          hint="Shown callbacks scored weak at review time."
        />
      </Section>

      <Section title="Recurrence density (this device)">
        <MetricRow
          label="Density score"
          value={`${Math.round(recurrence.densityScore * 100)}%`}
          hint={`${recurrence.entryCount} reflections · ${recurrence.recurringThemeCount} recurring themes · ${recurrence.repeatedPhraseCount} repeated phrases.`}
        />
        <MetricRow
          label="Single-mention entities"
          value={String(recurrence.singleMentionEntityCount)}
        />
        <MetricRow
          label="Magic candidate signal"
          value={recurrence.hasMagicCandidate ? "Present" : "Not yet"}
        />
        <MetricRow
          label="Recurrence prompt gating"
          value={recurrence.suppressed ? "Suppressed" : "Eligible"}
          hint={recurrence.suppressionReason ?? undefined}
        />
      </Section>

      <Section title="First-week funnel drop-off">
        <MetricRow
          label="Linear funnel completion"
          value={formatRetentionCoreRate(funnel.linearCompletionRate)}
          hint={`${funnel.linearStagesReached} / ${funnel.linearStagesTotal} stages on this device.`}
        />
        <MetricRow
          label="Drop-off stage"
          value={funnel.dropOffLabel ?? "Complete through linear funnel"}
        />
        <div className="mt-3 space-y-2">
          {funnel.stages.map((row) => (
            <div
              key={row.stage}
              className="flex items-center justify-between rounded-lg border border-white/5 bg-black/20 px-3 py-2"
            >
              <span className={row.reached ? "text-zinc-300" : "text-zinc-600"}>{row.label}</span>
              <span className="text-xs tabular-nums text-zinc-500">
                {row.at ? row.at.slice(0, 16) : row.reached ? "yes" : "—"}
              </span>
            </div>
          ))}
        </div>
      </Section>
    </div>
  );
}
