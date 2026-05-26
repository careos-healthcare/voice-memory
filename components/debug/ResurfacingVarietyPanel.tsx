"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { RESURFACING_MODE_LABELS } from "@/lib/resurfacing/return-modes";
import type { ResurfacingVarietyReport } from "@/types/resurfacing-variety";

export function ResurfacingVarietyPanel({ report }: { report: ResurfacingVarietyReport }) {
  if (!report.hasData) {
    return (
      <p className="text-sm text-zinc-500">
        No resurfacing mode events on this device yet. Open the homepage with a callback
        surfaced, or record again from a return prompt.
      </p>
    );
  }

  return (
    <div className="space-y-8">
      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Frequency restraint</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.frequencyGates.map((row) => (
            <Card
              key={row.label}
              className={
                row.active
                  ? "border-amber-500/20 bg-amber-950/10"
                  : "border-white/[0.06] bg-zinc-900/40"
              }
            >
              <CardContent className="py-4 text-sm">
                <p className={row.active ? "text-amber-200/90" : "text-zinc-400"}>
                  {row.label}
                  {row.active ? " · active" : " · off"}
                </p>
                <p className="mt-2 text-xs leading-relaxed text-zinc-600">{row.plain}</p>
              </CardContent>
            </Card>
          ))}
        </div>
        <p className="mt-3 text-xs leading-relaxed text-zinc-600">{report.changeDetectionPlain}</p>
        <p className="mt-2 text-xs leading-relaxed text-zinc-600">{report.naturalVoicePlain}</p>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Recent mode window</p>
        <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
          <CardContent className="py-4 text-sm text-zinc-400">
            {report.recentModes.length === 0 ? (
              <p>No modes in the last five resurfacing events.</p>
            ) : (
              <p>
                {report.recentModes
                  .map((mode) => RESURFACING_MODE_LABELS[mode])
                  .join(" → ")}
              </p>
            )}
          </CardContent>
        </Card>
      </section>

      {report.repetitionWarnings.length > 0 ? (
        <section>
          <p className="text-xs uppercase tracking-wider text-zinc-600">Repetition warnings</p>
          <Card className="mt-3 border-amber-500/20 bg-amber-950/10">
            <CardContent className="space-y-2 py-4 text-sm">
              {report.repetitionWarnings.map((warning) => (
                <p
                  key={warning.message}
                  className={
                    warning.severity === "concern"
                      ? "text-amber-200/90"
                      : "text-zinc-400"
                  }
                >
                  {warning.message}
                </p>
              ))}
            </CardContent>
          </Card>
        </section>
      ) : null}

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Mode distribution</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.modeDistribution.map((row) => (
            <Card key={row.mode} className="border-white/[0.06] bg-zinc-900/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-400">
                  {row.label}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-1 text-sm text-zinc-500">
                <p>
                  shown {row.shown} · opened {row.opened} ({row.openRate}%)
                </p>
                <p>reflection after {row.reflectionAfter} ({row.reflectionRate}%)</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {report.overusedPhrases.length > 0 ? (
        <section>
          <p className="text-xs uppercase tracking-wider text-zinc-600">Overused phrases</p>
          <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
            <CardContent className="py-4">
              <ul className="space-y-3 text-sm">
                {report.overusedPhrases.map((row) => (
                  <li key={row.phrase} className="border-b border-white/5 pb-3 last:border-0">
                    <p className="text-zinc-400">&ldquo;{row.phrase}&rdquo;</p>
                    <p className="mt-1 text-xs text-zinc-600">
                      ×{row.count} · {row.plain}
                    </p>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        </section>
      ) : null}

      {report.cadenceClusters.length > 0 ? (
        <section>
          <p className="text-xs uppercase tracking-wider text-zinc-600">
            Emotional cadence clustering
          </p>
          <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
            <CardContent className="py-4">
              <ul className="space-y-3 text-sm">
                {report.cadenceClusters.map((row) => (
                  <li
                    key={row.cadenceKey}
                    className="border-b border-white/5 pb-3 last:border-0"
                  >
                    <p className="text-zinc-300">{row.cadenceKey}</p>
                    <p className="mt-1 text-zinc-500">&ldquo;{row.sampleLine}&rdquo;</p>
                    <p className="mt-1 text-xs text-zinc-600">
                      ×{row.count} · {row.plain}
                    </p>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        </section>
      ) : null}
    </div>
  );
}
