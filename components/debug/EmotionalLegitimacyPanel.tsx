"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadEmotionalLegitimacyJson } from "@/lib/debug/emotional-legitimacy-review";
import type { EmotionalLegitimacyReport } from "@/types/social-proof";

function ScoreCard({ label, value }: { label: string; value: number }) {
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

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; text: string; detail?: string; score?: number; reason?: string }>;
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
                <p>{row.text}</p>
                {row.reason ? <p className="mt-1 text-xs text-zinc-600">{row.reason}</p> : null}
                {row.detail ? <p className="mt-1 text-xs text-zinc-600">{row.detail}</p> : null}
                {row.score !== undefined ? (
                  <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                    score {row.score}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function EmotionalLegitimacyPanel({ report }: { report: EmotionalLegitimacyReport }) {
  const { scores } = report;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Trust, residue, and revisit authenticity — without fake community energy.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadEmotionalLegitimacyJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <ScoreCard label="Overall" value={scores.overall} />
        <ScoreCard label="Trust strength" value={scores.trustStrength} />
        <ScoreCard label="Emotional residue" value={scores.emotionalResidue} />
        <ScoreCard label="Revisit authenticity" value={scores.revisitAuthenticity} />
        <ScoreCard label="Genericity risk" value={scores.genericityRisk} />
        <ScoreCard label="Overclaim risk" value={scores.overclaimRisk} />
        <ScoreCard label="Silence quality" value={scores.silenceQuality} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Strongest believable lines"
          rows={report.strongestBelievableLines}
          empty="No believable lines scored yet."
        />
        <LineList
          title="Weakest artificial-feeling lines"
          rows={report.weakestArtificialLines}
          empty="No weak lines flagged."
        />
        <LineList
          title="Callbacks remembered later"
          rows={report.rememberedLaterCallbacks.map((row) => ({
            id: row.callbackId,
            text: row.text,
            detail: [
              row.remembered72h ? "72h" : null,
              row.delayedRevisit ? "delayed revisit" : null,
              row.delayedReflection ? "delayed reflection" : null,
              row.copiedReopened ? "copied reopened" : null,
            ]
              .filter(Boolean)
              .join(" · "),
            score: row.score,
          }))}
          empty="No remembered-later callbacks yet."
        />
        <LineList
          title="Lines ignored instantly"
          rows={report.ignoredInstantlyLines}
          empty="No ignored lines recorded."
        />
      </div>
    </div>
  );
}
