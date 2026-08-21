"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ReopenPayoffDebugReport } from "@/lib/refinement/reopen-payoff";
import { REOPEN_PAYOFF_STRONG } from "@/lib/refinement/reopen-payoff";

function MetricCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        {hint ? <p className="mt-1 text-xs leading-relaxed text-zinc-600">{hint}</p> : null}
      </CardContent>
    </Card>
  );
}

export function ReopenPayoffDebugPanel({ report }: { report: ReopenPayoffDebugReport }) {
  return (
    <div className="space-y-6">
      <section className="grid gap-4 sm:grid-cols-3">
        <MetricCard
          label="Avg payoff score"
          value={report.hasData ? String(report.avgPayoffScore) : "—"}
          hint={`Strong threshold ${REOPEN_PAYOFF_STRONG}`}
        />
        <MetricCard
          label="Strong reopen moments"
          value={String(report.strongMomentCount)}
          hint="Max one surfaced per revisit"
        />
        <MetricCard
          label="Revisit conversion after payoff"
          value={report.revisitConversionAfterPayoff}
          hint="Revisits that led to a new reflection"
        />
      </section>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">
            Strongest reopen moments
          </CardTitle>
        </CardHeader>
        <CardContent>
          {report.moments.length === 0 ? (
            <p className="text-sm text-zinc-500">
              Revisit older entries with contrast to rank payoff moments.
            </p>
          ) : (
            <ul className="space-y-4">
              {report.moments.map((row) => (
                <li
                  key={`${row.entryId}-${row.anchorEntryId}`}
                  className="space-y-2 border-b border-white/5 pb-4 last:border-0"
                >
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <p className="text-sm text-zinc-200">{row.firstLine}</p>
                    <span className="shrink-0 text-xs tabular-nums text-violet-300/90">
                      payoff {row.payoffScore}
                    </span>
                  </div>
                  {row.pastQuote && row.currentQuote ? (
                    <div className="space-y-1 text-xs text-zinc-500">
                      <p>&ldquo;{row.pastQuote}&rdquo;</p>
                      <p className="text-zinc-400">&ldquo;{row.currentQuote}&rdquo;</p>
                    </div>
                  ) : null}
                  <p className="text-xs tabular-nums text-zinc-600">
                    {row.entryId.slice(0, 8)} · {row.gapDays}d gap
                    {row.hasAudio ? " · audio pair" : ""}
                    {row.signals.length > 0 ? ` · ${row.signals.join(", ")}` : ""}
                  </p>
                  <p className="text-xs tabular-nums text-zinc-600">
                    {row.revisitCount} revisit{row.revisitCount === 1 ? "" : "s"} ·{" "}
                    {row.reflectionAfterPayoff} reflection
                    {row.reflectionAfterPayoff === 1 ? "" : "s"} · {row.conversionRate}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
