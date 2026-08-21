"use client";

import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { downloadEmotionalIntegrityReviewJson } from "@/lib/debug/emotional-integrity-review";
import type { EmotionalIntegrityReviewReport } from "@/types/emotional-integrity-layer";

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

function WarningList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; label: string; detail: string }>;
  empty: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          <ul className="space-y-2">
            {rows.map((row) => (
              <li
                key={row.id}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p className="font-medium text-zinc-200">{row.label}</p>
                <p className="mt-1 text-xs text-zinc-500">{row.detail}</p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function EmotionalIntegrityPanel({ report }: { report: EmotionalIntegrityReviewReport }) {
  const { integrity } = report;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Consolidation founder review — integrity, deduplication, removal, and durability in one pass.
        </p>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => downloadEmotionalIntegrityReviewJson(report)}
        >
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      {integrity.founderWarnings.length > 0 ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3">
          <p className="text-xs uppercase tracking-wider text-amber-300/80">Founder warnings</p>
          <ul className="mt-2 space-y-1 text-sm text-amber-100">
            {integrity.founderWarnings.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard label="Emotional density" value={integrity.emotionalDensityScore} />
        <MetricCard label="Integrity warnings" value={integrity.warnings.length} />
        <MetricCard label="Overlap score" value={report.simplicity.overlapScore} />
        <MetricCard label="Continuity risk" value={report.durability.continuityRiskScore} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <WarningList
          title="Weakest artificial-feeling callbacks"
          rows={report.weakestArtificialCallbacks.map((row) => ({
            id: row.id,
            label: row.text,
            detail: row.reason,
          }))}
          empty="No weak callbacks flagged."
        />
        <WarningList
          title="Repetitive emotional structures"
          rows={report.repetitiveStructures.map((row) => ({
            id: row.id,
            label: `${row.label} (${row.count}×)`,
            detail: row.examples.join(" · "),
          }))}
          empty="No repetitive structures detected."
        />
        <WarningList
          title="Manipulation risk"
          rows={report.manipulationRisk}
          empty="No manipulation patterns detected."
        />
        <WarningList
          title="Monetization trust risk"
          rows={report.monetizationTrustRisk}
          empty="No monetization trust issues."
        />
        <WarningList
          title="Sharing cringe risk"
          rows={report.sharingCringeRisk}
          empty="No sharing cringe signals."
        />
        <WarningList
          title="Callback fatigue"
          rows={report.callbackFatigue}
          empty="No callback fatigue."
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Restraint recommendations</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {integrity.restraintRecommendations.map((row) => (
                <li key={row.id} className="rounded-lg border border-white/[0.06] px-3 py-2">
                  <span className="text-zinc-300">{row.text}</span>
                  <span className="ml-2 text-[10px] uppercase tracking-wider text-zinc-600">{row.action}</span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Safe to remove</CardTitle>
          </CardHeader>
          <CardContent>
            {report.removal.safeToRemove.length === 0 ? (
              <p className="text-sm text-zinc-500">Nothing ranked safe to remove yet.</p>
            ) : (
              <ul className="space-y-2 text-sm text-zinc-400">
                {report.removal.safeToRemove.slice(0, 6).map((row) => (
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
