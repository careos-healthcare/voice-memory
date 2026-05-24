"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadSacrednessReviewJson } from "@/lib/debug/sacredness-review";
import type { SacrednessReviewReport } from "@/types/sacredness-layer";

function MetricCard({ label, value }: { label: string; value: string | number }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
      </CardContent>
    </Card>
  );
}

export function SacrednessReviewPanel({ report }: { report: SacrednessReviewReport }) {
  const { sacredness } = report;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Sacredness preservation — rarity, silence value, and emotional restraint escalation.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadSacrednessReviewJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      {sacredness.founderWarnings.length > 0 ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3">
          <p className="text-xs uppercase tracking-wider text-amber-300/80">Founder warnings</p>
          <ul className="mt-2 space-y-1 text-sm text-amber-100">
            {sacredness.founderWarnings.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard label="Sacredness score" value={sacredness.sacrednessScore} />
        <MetricCard label="Emotional rarity" value={sacredness.emotionalRarityScore} />
        <MetricCard label="Silence value" value={sacredness.silenceValueScore} />
        <MetricCard label="Silence ratio" value={`${report.silenceRatio}%`} />
        <MetricCard label="Escalation level" value={report.escalation.level} />
        <MetricCard label="Fatigue risk" value={report.fatigueRisk} />
        <MetricCard label="Resurfacing drift" value={report.resurfacingDrift.toFixed(1)} />
        <MetricCard label="Silence-first" value={report.silenceFirst.active ? "Active" : "Off"} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Inflation warnings</CardTitle>
          </CardHeader>
          <CardContent>
            {sacredness.inflationWarnings.length === 0 ? (
              <p className="text-sm text-zinc-500">No inflation signals.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {sacredness.inflationWarnings.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                    <p className="text-zinc-300">{row.label}</p>
                    <p className="mt-1 text-xs text-zinc-600">{row.detail}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Non-intervention</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.nonIntervention.conclusions.map((row) => (
                <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                  <p className="text-zinc-300">{row.text}</p>
                  <p className="mt-1 text-xs text-zinc-600">confidence {row.confidence}</p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Preserved strong callbacks</CardTitle>
          </CardHeader>
          <CardContent>
            {report.preservedStrongCallbacks.length === 0 ? (
              <p className="text-sm text-zinc-500">None identified yet.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {report.preservedStrongCallbacks.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                    {row.text} · {row.score}
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Diluted callbacks</CardTitle>
          </CardHeader>
          <CardContent>
            {report.dilutedCallbacks.length === 0 ? (
              <p className="text-sm text-zinc-500">No dilution detected.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {report.dilutedCallbacks.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                    <p className="text-zinc-300">{row.text}</p>
                    <p className="mt-1 text-xs text-zinc-600">{row.reason}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Density trend</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-1 text-sm text-zinc-400">
              {report.inflationTrend.map((row) => (
                <li key={row.period}>
                  {row.period}: {row.density} callbacks/entry · {row.resurfacingCount} resurfacing
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Earned resurfacing</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="mb-2 text-sm text-zinc-500">
              {report.earnedResurfacing.earnedCount} earned · {report.earnedResurfacing.decayedCount} decayed
            </p>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.earnedResurfacing.rows.slice(0, 6).map((row) => (
                <li key={row.noteId} className="rounded-lg border border-white/[0.06] px-3 py-2">
                  <p className="text-zinc-300">{row.text}</p>
                  <p className="mt-1 text-xs text-zinc-600">
                    {row.earned ? "Earned" : "Decayed"} · {row.decayReason}
                  </p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
