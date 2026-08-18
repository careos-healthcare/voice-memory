"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  FOUNDER_CATEGORY_POSITIONING,
  FOUNDER_EVOLVING_VALIDATION_QUESTIONS,
  FOUNDER_MENTAL_MODEL_DISTINCTION,
  FOUNDER_ROADMAP_GATE,
  FOUNDER_TWO_WEEK_SUCCESS_CRITERIA,
  FOUNDER_VALIDATION_BEHAVIOR_GATE,
  FOUNDER_VALIDATION_INTERVIEW_TARGET,
  FOUNDER_VALIDATION_NOT_WATCHING,
  FOUNDER_VALIDATION_PHASE,
  FOUNDER_VALIDATION_PRIMARY_BEHAVIOR,
} from "@/lib/founder-test/founder-evolving-validation";
import type { FounderEvolvingValidationReport } from "@/types/founder-test";

interface FounderEvolvingValidationPanelProps {
  report: FounderEvolvingValidationReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

function verdictStyles(verdict: FounderEvolvingValidationReport["verdict"]): string {
  switch (verdict) {
    case "evolving_model_signal":
      return "border-emerald-500/25 bg-emerald-950/15";
    case "journal_mode":
      return "border-red-500/25 bg-red-950/15";
    case "mixed":
      return "border-amber-500/25 bg-amber-950/15";
    default:
      return "border-white/10 bg-zinc-900/40";
  }
}

export function FounderEvolvingValidationPanel({ report }: FounderEvolvingValidationPanelProps) {
  const q = FOUNDER_EVOLVING_VALIDATION_QUESTIONS;

  return (
    <section className="space-y-6">
      <Card className="border-white/10 bg-zinc-900/40">
        <CardHeader className="pb-2">
          <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
            Next 2 weeks — behavioral validation
          </p>
          <CardTitle className="text-lg text-white">{FOUNDER_VALIDATION_PHASE.paused}</CardTitle>
          <p className="mt-2 text-sm text-zinc-500 line-through">{FOUNDER_VALIDATION_PHASE.oldGoal}</p>
          <p className="text-sm font-medium text-zinc-200">{FOUNDER_VALIDATION_PHASE.newGoal}</p>
          <p className="mt-2 text-xs text-zinc-500">
            Target: {FOUNDER_VALIDATION_INTERVIEW_TARGET.label} founder interviews · highest-value
            output is whether people say “{FOUNDER_MENTAL_MODEL_DISTINCTION.success}” vs “
            {FOUNDER_MENTAL_MODEL_DISTINCTION.failure}”
          </p>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-zinc-400">
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">
              Success criteria (need evidence of all four)
            </p>
            <ul className="mt-2 list-inside list-disc space-y-1">
              {FOUNDER_TWO_WEEK_SUCCESS_CRITERIA.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
            <p className="mt-2 text-xs text-amber-200/80">{FOUNDER_VALIDATION_BEHAVIOR_GATE}</p>
          </div>
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">Not watching</p>
            <p className="mt-1 text-zinc-600">{FOUNDER_VALIDATION_NOT_WATCHING.join(" · ")}</p>
          </div>
          <p className="text-violet-100/90">{FOUNDER_VALIDATION_PRIMARY_BEHAVIOR}</p>
        </CardContent>
      </Card>

      <Card className={`border ${verdictStyles(report.verdict)}`}>
        <CardHeader className="pb-2">
          <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
            Validate before building more
          </p>
          <CardTitle className="text-lg text-white">Evolving understanding — behaviour check</CardTitle>
          <p className="text-sm leading-relaxed text-zinc-400">{report.mainQuestion}</p>
          <p className="mt-2 text-sm font-medium text-zinc-200">
            Verdict: {report.verdict.replace(/_/g, " ")}
          </p>
          <p className="text-sm text-zinc-500">{report.verdictLabel}</p>
        </CardHeader>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard
          title="1 · Working theory preferred"
          value={rateLabel(report.workingTheoryPreferredRate)}
          hint={q.framingAccuracy.passSignal}
        />
        <MetricCard
          title="2 · Discover “good” expectation"
          value={rateLabel(report.discoverExpectationGoodRate)}
          hint="Good = confidence changed, archive changed its mind, theories moved"
        />
        <MetricCard
          title="3 · Theory curiosity (interview)"
          value={rateLabel(report.interviewTheoryCuriosityRate)}
          hint={q.theoryCuriosity.passSignal}
        />
        <MetricCard
          title="4 · Returned to check (interview)"
          value={rateLabel(report.interviewReturnedToCheckRate)}
          hint={q.returnedToCheck.passSignal}
        />
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">This device (automatic)</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-2 text-sm text-zinc-400">
          <p>
            Theory Curiosity Rate:{" "}
            <span className="font-medium text-zinc-200">
              {rateLabel(report.device.theoryCuriosityRate)}
            </span>{" "}
            <span className="text-zinc-600">
              ({report.device.theoryCuriosityResponses} in-app prompts)
            </span>
          </p>
          <p>
            Returned to Check Archive View Rate:{" "}
            <span className="font-medium text-zinc-200">
              {rateLabel(report.device.returnedToCheckArchiveViewRate)}
            </span>{" "}
            <span className="text-zinc-600">
              ({report.device.returnedToCheckCount} / {report.device.firstWorkingTheorySeenCount}{" "}
              first theories, ≥24h)
            </span>
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/30">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-400">Interview script (after first working theory)</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-zinc-400">
          <div>
            <p className="font-medium text-zinc-300">{q.framingAccuracy.prompt}</p>
            <ul className="mt-1 list-inside list-disc text-zinc-500">
              {q.framingAccuracy.options.map((o) => (
                <li key={o.value}>{o.label}</li>
              ))}
            </ul>
          </div>
          <div>
            <p className="font-medium text-zinc-300">{q.discoverExpectation.prompt}</p>
            <p className="mt-1 text-xs text-emerald-400/90">
              Good: {q.discoverExpectation.goodExamples.join(" · ")}
            </p>
            <p className="mt-1 text-xs text-red-400/80">
              Weak: {q.discoverExpectation.weakExamples.join(" · ")}
            </p>
          </div>
          <p>
            <span className="font-medium text-zinc-300">{q.theoryCuriosity.prompt}</span>
          </p>
          <p>
            <span className="font-medium text-zinc-300">{q.returnedToCheck.prompt}</span>
          </p>
        </CardContent>
      </Card>

      <Card className="border-emerald-500/15 bg-emerald-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-emerald-100">Roadmap gate (after interviews)</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-zinc-400">
          <p className="text-emerald-200/90">{FOUNDER_ROADMAP_GATE.buildTheoryAccuracyHistory}</p>
          <p className="text-red-200/80">{FOUNDER_ROADMAP_GATE.fixLoopNotHistory}</p>
          <p className="border-t border-white/5 pt-3 text-zinc-300">
            {FOUNDER_CATEGORY_POSITIONING}
          </p>
        </CardContent>
      </Card>

      <ul className="space-y-1 text-xs text-zinc-600">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>

      <p className="text-xs leading-relaxed text-zinc-600">
        Do not build Flutter parity, notifications, Theory v2, or another intelligence engine during
        this window. {FOUNDER_VALIDATION_PHASE.ifNo} / {FOUNDER_VALIDATION_PHASE.ifYes}
      </p>
    </section>
  );
}

function MetricCard({
  title,
  value,
  hint,
}: {
  title: string;
  value: string;
  hint: string;
}) {
  return (
    <Card className="border-white/10 bg-zinc-900/50">
      <CardHeader className="pb-2">
        <CardTitle className="text-xs leading-snug text-zinc-500">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold text-white">{value}</p>
        <p className="mt-2 text-xs leading-relaxed text-zinc-600">{hint}</p>
      </CardContent>
    </Card>
  );
}
