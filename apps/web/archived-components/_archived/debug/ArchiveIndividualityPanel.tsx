"use client";

import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { downloadArchiveIndividualityReviewJson } from "@/lib/debug/archive-individuality-review";
import type { ArchiveIndividualityReviewReport } from "@/types/archive-individuality";

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

export function ArchiveIndividualityPanel({ report }: { report: ArchiveIndividualityReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Internal individuality profile — no personality typing, no user-visible labels.
        </p>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => downloadArchiveIndividualityReviewJson(report)}
        >
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      {report.founderWarnings.length > 0 ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3">
          <p className="text-xs uppercase tracking-wider text-amber-300/80">Founder warnings</p>
          <ul className="mt-2 space-y-1 text-sm text-amber-100">
            {report.founderWarnings.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard label="Uniqueness score" value={report.profile.uniquenessScore} />
        <MetricCard label="Vocabulary diversity" value={report.vocabularyDiversity} />
        <MetricCard label="Phrasing collapse risk" value={report.phrasingCollapseRisk} />
        <MetricCard label="Callback similarity" value={report.callbackSimilarityScore} />
        <MetricCard label="Revisit rhythm" value={report.revisitRhythmUniqueness} />
        <MetricCard label="Silence behavior" value={report.silenceBehaviorUniqueness} />
        <MetricCard label="Protected phrases" value={report.voiceTexture.protectedPhraseCount} />
        <MetricCard label="Longitudinal trend" value={report.longitudinal.becomingMoreUnique ? "↑ unique" : report.longitudinal.converging ? "↓ converging" : "—"} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Uniqueness markers</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.uniquenessMarkers.map((row) => (
                <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                  <p className="text-zinc-300">{row.label}</p>
                  <p className="mt-1 text-xs text-zinc-600">{row.detail}</p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Repeated structures</CardTitle>
          </CardHeader>
          <CardContent>
            {report.repeatedStructures.length === 0 ? (
              <p className="text-sm text-zinc-500">No repeated callback structures.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {report.repeatedStructures.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                    {row.label} · {row.count}×
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Voice texture markers</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.voiceTexture.markers.slice(0, 8).map((row) => (
                <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                  <span className="text-[10px] uppercase tracking-wider text-zinc-600">{row.kind}</span>
                  <p className="mt-1 text-zinc-300">{row.text}</p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Longitudinal signals</CardTitle>
          </CardHeader>
          <CardContent>
            {report.longitudinal.signals.length === 0 ? (
              <p className="text-sm text-zinc-500">No convergence signals yet.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {report.longitudinal.signals.map((row) => (
                  <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                    <p className="text-zinc-300">{row.label}</p>
                    <p className="mt-1 text-xs text-zinc-600">{row.detail}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
