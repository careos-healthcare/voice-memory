"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  BehaviorFunnelStep,
  BehaviorInsightLine,
  BehaviorTruthReport,
  CopyEffectivenessRow,
  ProductPressureWarning,
  SurfaceEffectivenessRow,
} from "@/types/behavior-truth";
import { buildInterruptionTimingReport } from "@/lib/capture/interruption-timing";
import { buildVulnerabilityTimingReport } from "@/lib/capture/vulnerability-timing";
import type { ReadVsSpeakReport, ReflexScoreSnapshot } from "@/types/reflex";

function FunnelCard({ step }: { step: BehaviorFunnelStep }) {
  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-400">{step.label}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        <p className="text-2xl tabular-nums text-zinc-200">{step.percent}%</p>
        <p className="text-xs text-zinc-600">{step.sampleNote}</p>
        <p className="leading-relaxed text-zinc-500">{step.interpretation}</p>
      </CardContent>
    </Card>
  );
}

function SurfaceRow({ row }: { row: SurfaceEffectivenessRow }) {
  return (
    <li className="border-b border-white/5 pb-3 last:border-0">
      <div className="flex justify-between gap-2">
        <span className="text-zinc-300">{row.label}</span>
        <span className="text-xs text-zinc-600">
          seen {row.seen} · open {row.openRate}% · reflect {row.reflectionRate}%
        </span>
      </div>
      <p className="mt-1 text-xs leading-relaxed text-zinc-600">{row.plain}</p>
    </li>
  );
}

function CopyRow({ row }: { row: CopyEffectivenessRow }) {
  return (
    <li className="border-b border-white/5 pb-3 last:border-0">
      <p className="text-sm text-zinc-400">&ldquo;{row.preview}&rdquo;</p>
      <p className="mt-1 text-xs text-zinc-600">
        shown {row.shown} · open {row.openRate}% · after {row.reflectionRate}%
        {row.generic ? " · generic" : ""}
      </p>
      <p className="mt-1 text-xs leading-relaxed text-zinc-600">{row.plain}</p>
    </li>
  );
}

function InsightList({ insights }: { insights: BehaviorInsightLine[] }) {
  return (
    <ul className="space-y-3">
      {insights.map((insight) => (
        <li key={insight.text} className="leading-relaxed text-zinc-300">
          {insight.text}
          <span className="mt-1 block text-xs text-zinc-600">
            {insight.confidence} confidence · {insight.basedOn}
          </span>
        </li>
      ))}
    </ul>
  );
}

function ReadVsSpeakSection({ report }: { report: ReadVsSpeakReport }) {
  const { metrics } = report;
  return (
    <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
      <CardContent className="space-y-3 py-4 text-sm">
        <p className="text-zinc-400">
          Avg read before record:{" "}
          <span className="text-zinc-200">
            {metrics.avgSecondsBeforeRecord != null
              ? `${metrics.avgSecondsBeforeRecord}s`
              : "—"}
          </span>
        </p>
        <p className="text-zinc-500">
          Callback opens without record: {metrics.callbackOpensWithoutRecord} ·
          Reopens without record: {metrics.repeatedReopenWithoutRecord} · Scroll
          signals: {metrics.scrollBeforeRecordSignals}
        </p>
        {metrics.consumableContinuityRisk ? (
          <p className="text-amber-200/90">Consumable continuity risk</p>
        ) : null}
        {metrics.passiveReadingLikely ? (
          <p className="text-amber-200/90">Passive reading likely</p>
        ) : null}
        {report.warnings.length > 0 ? (
          <ul className="space-y-2 text-xs text-zinc-600">
            {report.warnings.map((w) => (
              <li key={w.id}>{w.message}</li>
            ))}
          </ul>
        ) : (
          <p className="text-xs text-zinc-600">No read-vs-speak warnings on this device.</p>
        )}
      </CardContent>
    </Card>
  );
}

function ReflexScoreSection({ score }: { score: ReflexScoreSnapshot }) {
  const rows: Array<{ label: string; value: number }> = [
    { label: "Resurfacing → immediate record", value: score.resurfacingToImmediateRecord },
    { label: "Unresolved return", value: score.unresolvedReturnScore },
    { label: "Speed to speak", value: score.speedToSpeakScore },
    { label: "Emotional recurrence timing", value: score.emotionalRecurrenceTiming },
    { label: "Late-night reflex", value: score.lateNightReflexUsage },
    { label: "After conflict repeat", value: score.conflictRepeatScore },
  ];
  return (
    <Card className="mt-3 border-violet-500/20 bg-violet-950/10">
      <CardContent className="py-4 text-sm">
        <p className="text-2xl tabular-nums text-zinc-200">{score.overall}</p>
        <p className="text-xs text-zinc-600">Overall reflex score (speaking-weighted, not engagement)</p>
        <ul className="mt-4 space-y-2">
          {rows.map((row) => (
            <li key={row.label} className="flex justify-between gap-2 text-zinc-500">
              <span>{row.label}</span>
              <span className="tabular-nums text-zinc-300">{row.value}</span>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}

function PressureList({ warnings }: { warnings: ProductPressureWarning[] }) {
  return (
    <ul className="space-y-2">
      {warnings.map((warning) => (
        <li
          key={warning.plain}
          className={
            warning.severity === "concern"
              ? "text-amber-200/90"
              : "text-zinc-400"
          }
        >
          {warning.plain}
        </li>
      ))}
    </ul>
  );
}

export function BehaviorTruthPanel({ report }: { report: BehaviorTruthReport }) {
  const interruption = buildInterruptionTimingReport();
  const vulnerability = buildVulnerabilityTimingReport();

  return (
    <div className="space-y-8">
      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Time to vulnerable speech</p>
        <Card className="mt-3 border-violet-500/20 bg-violet-950/10">
          <CardContent className="space-y-2 py-4 text-sm text-zinc-400">
            <p>
              App open → mic:{" "}
              <span className="text-zinc-200">
                {vulnerability.medianAppOpenToMicVisibleMs ??
                  vulnerability.medianTimeToMicMs ??
                  "—"}
                ms
              </span>
            </p>
            <p>
              App open → record:{" "}
              <span className="text-zinc-200">
                {vulnerability.medianAppOpenToRecordingStartedMs ?? "—"}ms
              </span>
            </p>
            <p>
              Median hesitation / silence before speech:{" "}
              <span className="text-zinc-200">
                {vulnerability.medianHesitationMs ?? "—"}ms /{" "}
                {vulnerability.medianSilenceBeforeSpeechMs ?? "—"}ms
              </span>
            </p>
            <p>
              Vulnerable phrase latency:{" "}
              <span className="text-zinc-200">
                {vulnerability.medianTimeToVulnerablePhraseMs ?? "—"}ms
              </span>
            </p>
            <p>
              Direct-to-mic conversion:{" "}
              <span className="text-zinc-200">
                {vulnerability.directToMicConversionPercent ?? "—"}%
              </span>
            </p>
            <p className="text-xs text-zinc-600">{vulnerability.scopeNote}</p>
          </CardContent>
        </Card>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Interruption timing</p>
        <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
          <CardContent className="space-y-2 py-4 text-sm text-zinc-500">
            <p>{interruption.plain}</p>
            <p className="text-zinc-400">
              Effectiveness (recording): {interruption.recordingEffectivenessPercent ?? "—"}%
              · Silence: {interruption.silenceEffectivenessPercent ?? "—"}%
            </p>
            <p className="text-xs text-zinc-600">
              Shown {interruption.metrics.shown} · suppressed {interruption.metrics.suppressed}{" "}
              · led to record {interruption.metrics.ledToRecording} · read{" "}
              {interruption.metrics.ledToReading}
            </p>
          </CardContent>
        </Card>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Plain-language insights</p>
        <Card className="mt-3 border-violet-500/20 bg-violet-950/10">
          <CardContent className="py-4">
            <InsightList insights={report.insights} />
          </CardContent>
        </Card>
      </section>

      {report.productPressure.length > 0 ? (
        <section>
          <p className="text-xs uppercase tracking-wider text-zinc-600">Product pressure</p>
          <Card className="mt-3 border-amber-500/20 bg-amber-950/10">
            <CardContent className="py-4 text-sm">
              <PressureList warnings={report.productPressure} />
            </CardContent>
          </Card>
        </section>
      ) : null}

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Read vs speak</p>
        <ReadVsSpeakSection report={report.readVsSpeak} />
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Reflex decompression score</p>
        <ReflexScoreSection score={report.reflexScore} />
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Funnels</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.funnels
            .filter(
              (step) =>
                !step.id.startsWith("clarity_") &&
                !step.id.startsWith("reflex_") &&
                step.id !== "thought_pattern_resurface_to_reflection",
            )
            .map((step) => (
            <FunnelCard key={step.id} step={step} />
          ))}
        </div>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Reflex capture</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.funnels
            .filter((step) => step.id.startsWith("reflex_"))
            .map((step) => (
              <FunnelCard key={step.id} step={step} />
            ))}
        </div>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">
          Thinking out loud (clarity)
        </p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.funnels
            .filter(
              (step) =>
                step.id.startsWith("clarity_") ||
                step.id === "thought_pattern_resurface_to_reflection",
            )
            .map((step) => (
              <FunnelCard key={step.id} step={step} />
            ))}
        </div>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Return timing</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.returnTiming.map((metric) => (
            <Card key={metric.label} className="border-white/[0.06] bg-zinc-900/40">
              <CardContent className="py-4 text-sm">
                <p className="text-zinc-400">{metric.label}</p>
                <p className="mt-1 text-xl tabular-nums text-zinc-200">
                  {metric.medianHours !== null ? `${metric.medianHours}h` : "—"}
                </p>
                <p className="mt-2 leading-relaxed text-zinc-600">{metric.plain}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">User return style</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.userSegments.map((row) => (
            <Card key={row.segment} className="border-white/[0.06] bg-zinc-900/40">
              <CardContent className="py-4 text-sm">
                <p className="text-zinc-300">{row.label}</p>
                <p className="mt-2 leading-relaxed text-zinc-600">{row.plain}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Surface effectiveness</p>
        <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
          <CardContent className="py-4">
            <ul>
              {report.surfaces.map((row) => (
                <SurfaceRow key={row.id} row={row} />
              ))}
            </ul>
          </CardContent>
        </Card>
      </section>

      {report.strongestCopy.length > 0 || report.weakCopy.length > 0 ? (
        <section className="grid gap-4 sm:grid-cols-2">
          {report.strongestCopy.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-600">Strong resurfacing copy</p>
              <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
                <CardContent className="py-4">
                  <ul>{report.strongestCopy.map((row) => <CopyRow key={row.lineKey} row={row} />)}</ul>
                </CardContent>
              </Card>
            </div>
          ) : null}
          {report.weakCopy.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-600">Weak / generic copy</p>
              <Card className="mt-3 border-white/[0.06] bg-zinc-900/40">
                <CardContent className="py-4">
                  <ul>{report.weakCopy.map((row) => <CopyRow key={row.lineKey} row={row} />)}</ul>
                </CardContent>
              </Card>
            </div>
          ) : null}
        </section>
      ) : null}

      <section>
        <p className="text-xs uppercase tracking-wider text-zinc-600">Mobile behavior</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {report.mobile.map((row) => (
            <Card key={row.label} className="border-white/[0.06] bg-zinc-900/40">
              <CardContent className="py-4 text-sm">
                <p className="text-zinc-400">{row.label}</p>
                <p className="mt-1 text-lg text-zinc-200">{row.value}</p>
                <p className="mt-2 leading-relaxed text-zinc-600">{row.plain}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}
