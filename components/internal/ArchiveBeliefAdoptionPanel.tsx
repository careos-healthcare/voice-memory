"use client";

import {
  ARCHIVE_BELIEF_BUILD_IF_VALIDATED,
  ARCHIVE_BELIEF_ROADMAP_FREEZE,
  ARCHIVE_BELIEF_SUCCESS_CRITERIA,
} from "@/lib/founder-test/belief-reframing-validation";
import type { ArchiveBeliefAdoptionReport } from "@/types/archive-belief";

interface ArchiveBeliefAdoptionPanelProps {
  report: ArchiveBeliefAdoptionReport;
}

export function ArchiveBeliefAdoptionPanel({ report }: ArchiveBeliefAdoptionPanelProps) {
  return (
    <section className="space-y-4 rounded-2xl border border-white/10 bg-zinc-900/30 p-6">
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">Archive belief</p>
        <h2 className="mt-2 text-lg font-semibold text-white">{report.title}</h2>
      </div>
      <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Metric label="Belief card viewed" value={report.beliefCardViewedCount} />
        <Metric label="Evidence expanded" value={report.beliefExpandedCount} />
        <Metric label="What changed viewed" value={report.beliefChangeViewedCount} />
        <Metric label="Timeline viewed" value={report.beliefTimelineViewedCount} />
        <Metric label="Discover opens" value={report.discoverOpenCount} />
        <Metric label="% opening belief card" value={formatRate(report.beliefCardOpenRate)} />
        <Metric label="% opening evidence" value={formatRate(report.evidenceOpenRate)} />
        <Metric
          label="% change section seen"
          value={formatRate(report.returnAfterBeliefChangeRate)}
        />
        <Metric label="% timeline seen" value={formatRate(report.timelineViewRate)} />
        <Metric
          label="Framing: understanding"
          value={formatRate(report.productFramingUnderstandingPct)}
        />
        <Metric
          label="Framing: insights"
          value={formatRate(report.productFramingInsightsPct)}
        />
        <Metric label="Interview sample (framing)" value={report.productFramingSampleSize} />
      </dl>
      <ul className="space-y-1 text-sm text-zinc-500">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>

      <div className="rounded-xl border border-amber-500/20 bg-amber-950/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-amber-200/80">
          {ARCHIVE_BELIEF_ROADMAP_FREEZE.title}
        </p>
        <p className="mt-2 text-sm text-zinc-300">
          Testing: {ARCHIVE_BELIEF_ROADMAP_FREEZE.hypothesis}
        </p>
        <p className="mt-1 text-sm text-zinc-500">Not: {ARCHIVE_BELIEF_ROADMAP_FREEZE.notHypothesis}</p>
        <p className="mt-3 text-xs font-medium text-zinc-500">Paused until validation</p>
        <p className="mt-1 text-xs text-zinc-600">{ARCHIVE_BELIEF_ROADMAP_FREEZE.paused.join(" · ")}</p>
      </div>

      <div className="rounded-xl border border-dashed border-white/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-zinc-500">Success criteria (in order)</p>
        <ol className="mt-3 space-y-4">
          {ARCHIVE_BELIEF_SUCCESS_CRITERIA.map((c) => (
            <li key={c.id} className="text-sm text-zinc-500">
              <p className="font-medium text-zinc-300">
                {c.rank}. {c.title}
              </p>
              <p className="mt-1 text-xs">{c.question}</p>
              {"passSignals" in c ? (
                <>
                  <ul className="mt-2 list-disc pl-4 text-xs">
                    {c.passSignals.map((s) => (
                      <li key={s} className="text-emerald-400/80">
                        {s}
                      </li>
                    ))}
                  </ul>
                  <ul className="mt-1 list-disc pl-4 text-xs">
                    {c.failSignals.map((s) => (
                      <li key={s} className="text-amber-400/80">
                        {s}
                      </li>
                    ))}
                  </ul>
                  {"failMeaning" in c ? (
                    <p className="mt-1 text-xs text-zinc-600">{c.failMeaning}</p>
                  ) : null}
                </>
              ) : null}
              {"want" in c ? (
                <>
                  <p className="mt-2 text-xs">
                    Want: {c.want}
                  </p>
                  <p className="text-xs">Avoid: {c.avoid}</p>
                  {"passMeaning" in c ? (
                    <p className="mt-1 text-xs text-emerald-400/70">{c.passMeaning}</p>
                  ) : null}
                </>
              ) : null}
              {"atFive" in c ? (
                <p className="mt-2 text-xs">
                  At 5: {c.atFive}. At 6: {c.atSix}. Fail: {c.fail}
                </p>
              ) : null}
            </li>
          ))}
        </ol>
      </div>

      <div className="rounded-xl border border-violet-500/15 bg-violet-950/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-violet-300/80">
          {ARCHIVE_BELIEF_BUILD_IF_VALIDATED.title}
        </p>
        <p className="mt-2 text-sm font-medium text-zinc-200">
          {ARCHIVE_BELIEF_BUILD_IF_VALIDATED.feature}
        </p>
        <p className="mt-1 text-xs text-zinc-500">
          Reinforces: “{ARCHIVE_BELIEF_BUILD_IF_VALIDATED.reinforces}”
        </p>
        <ul className="mt-2 list-disc pl-4 text-xs text-zinc-400">
          {ARCHIVE_BELIEF_BUILD_IF_VALIDATED.presents.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
        <p className="mt-2 text-xs text-zinc-600">
          Not: {ARCHIVE_BELIEF_BUILD_IF_VALIDATED.explicitlyNot.join("; ")}.
        </p>
      </div>
    </section>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-white/5 bg-black/20 px-4 py-3">
      <dt className="text-xs text-zinc-500">{label}</dt>
      <dd className="mt-1 text-xl font-semibold tabular-nums text-zinc-100">{value}</dd>
    </div>
  );
}

function formatRate(rate: number | null): string {
  if (rate === null) return "—";
  return `${rate}%`;
}
