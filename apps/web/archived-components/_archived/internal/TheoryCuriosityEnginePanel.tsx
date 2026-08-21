"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { TheoryCuriosityEngineReport } from "@/types/theory-curiosity-engine";

interface TheoryCuriosityEnginePanelProps {
  report: TheoryCuriosityEngineReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function TheoryCuriosityEnginePanel({ report }: TheoryCuriosityEnginePanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Theory Curiosity Engine</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Voluntary check-in desire — no streaks, reminders, or gamification. Compare curiosity to
          discover opens, 7-day return, paywall clicks, and subscription proxies.
        </p>
        <p className="mt-2 text-sm text-violet-200/80">{report.leadingIndicatorLine}</p>
        {report.curiosityRateRising === true ? (
          <p className="mt-1 text-sm text-emerald-300/90">
            Recent curiosity rate is rising vs the prior 30 days.
          </p>
        ) : report.curiosityRateRising === false ? (
          <p className="mt-1 text-sm text-zinc-500">
            Recent curiosity rate is flat or down vs the prior 30 days.
          </p>
        ) : null}
        <p className="mt-2 text-xs text-zinc-600">{report.measurementNote}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Metric label="Theory Curiosity Rate" value={`${report.theoryCuriosityRate}%`} />
        <Metric label="Curious (yes/maybe)" value={String(report.curiousCount)} />
        <Metric label="Total responses" value={String(report.totalResponses)} />
        <Metric
          label="Yes / Maybe / No"
          value={`${report.yesCount} / ${report.maybeCount} / ${report.noCount}`}
        />
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Curiosity funnel</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {report.funnel.map((step, index) => (
            <div
              key={step.id}
              className="rounded-lg border border-white/5 bg-black/20 px-3 py-3 text-sm"
            >
              <p className="font-medium text-zinc-300">
                {index > 0 ? "→ " : ""}
                {step.label}
              </p>
              <p className="mt-1 text-xs text-zinc-500">
                n={step.count} · from curious {rateLabel(step.rateFromCuriousPercent)}
                {step.rateFromPriorStepPercent !== null && index > 0 ? (
                  <> · from prior step {rateLabel(step.rateFromPriorStepPercent)}</>
                ) : null}
              </p>
            </div>
          ))}
        </CardContent>
      </Card>
    </section>
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
