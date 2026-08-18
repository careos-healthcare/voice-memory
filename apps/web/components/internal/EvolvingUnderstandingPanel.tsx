"use client";

import type { EvolvingUnderstandingReport } from "@/types/evolving-understanding";

interface EvolvingUnderstandingPanelProps {
  report: EvolvingUnderstandingReport;
}

export function EvolvingUnderstandingPanel({ report }: EvolvingUnderstandingPanelProps) {
  return (
    <section className="space-y-4 rounded-2xl border border-white/10 bg-zinc-900/30 p-6">
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
          Evolving understanding loop
        </p>
        <h2 className="mt-2 text-lg font-semibold text-white">Evolving understanding loop</h2>
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">{report.mainQuestion}</p>
      </div>
      <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Metric label="First working theory seen" value={report.firstBlindSpotSeenCount} />
        <Metric label="Evolving view card seen" value={report.evolvingViewCardSeenCount} />
        <Metric
          label="What happens next click rate"
          value={formatRate(report.whatHappensNextClickRate)}
        />
        <Metric
          label="Discover after first blind spot rate"
          value={formatRate(report.discoverAfterFirstBlindSpotRate)}
        />
        <Metric
          label="Returned to check archive view rate"
          value={formatRate(report.returnedToCheckArchiveViewRate)}
        />
        <Metric
          label="Discover after first blind spot (count)"
          value={report.discoverAfterFirstBlindSpotCount}
        />
      </dl>
      <ul className="space-y-1 text-sm text-zinc-500">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
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
