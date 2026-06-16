import type { ArchiveMoatReport } from "@/lib/internal/archive-moat-report";

export function ArchiveMoatReportPanel({ report }: { report: ArchiveMoatReport }) {
  return (
    <div className="space-y-6" data-testid="archive-moat-report-panel">
      <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4">
        <p className="text-xs uppercase tracking-wide text-zinc-600">{report.criticalQuestion}</p>
        <p className="mt-2 text-sm text-zinc-200">{report.criticalAnswer}</p>
        <dl className="mt-4 grid gap-3 sm:grid-cols-3">
          <div>
            <dt className="text-xs text-zinc-600">Moat responses</dt>
            <dd className="font-mono text-lg text-zinc-100">{report.totalMoatResponses}</dd>
          </div>
          <div>
            <dt className="text-xs text-zinc-600">Replaceable</dt>
            <dd className="font-mono text-lg text-zinc-100">
              {report.replaceablePercent ?? "—"}%
            </dd>
          </div>
          <div>
            <dt className="text-xs text-zinc-600">Hard to recreate</dt>
            <dd className="font-mono text-lg text-zinc-100">
              {report.irreplaceablePercent ?? "—"}%
            </dd>
          </div>
        </dl>
      </section>

      {report.perceptionDistribution.length > 0 ? (
        <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4">
          <h2 className="text-sm font-medium text-zinc-300">archive_moat_perception</h2>
          <ul className="mt-3 space-y-2 text-sm text-zinc-400">
            {report.perceptionDistribution.map((row) => (
              <li key={row.perception} className="flex justify-between gap-4">
                <span>{row.label}</span>
                <span className="font-mono text-zinc-500">
                  {row.count} ({row.sharePercent}%)
                </span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {report.attachmentByPerception.length > 0 ? (
        <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4">
          <h2 className="text-sm font-medium text-zinc-300">Attachment by perception</h2>
          <ul className="mt-3 space-y-2 text-sm text-zinc-400">
            {report.attachmentByPerception.map((row) => (
              <li key={row.perception} className="flex justify-between gap-4">
                <span>{row.label}</span>
                <span className="font-mono text-zinc-500">
                  avg {row.averageAttachmentScore ?? "—"} (n={row.count})
                </span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {report.returnRateByPerception.length > 0 ? (
        <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4">
          <h2 className="text-sm font-medium text-zinc-300">Return (7d) by perception</h2>
          <ul className="mt-3 space-y-2 text-sm text-zinc-400">
            {report.returnRateByPerception.map((row) => (
              <li key={row.perception} className="flex justify-between gap-4">
                <span>{row.label}</span>
                <span className="font-mono text-zinc-500">{row.returnRate ?? "—"}%</span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {report.conversionRateByPerception.length > 0 ? (
        <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4">
          <h2 className="text-sm font-medium text-zinc-300">Conversion (30d) by perception</h2>
          <ul className="mt-3 space-y-2 text-sm text-zinc-400">
            {report.conversionRateByPerception.map((row) => (
              <li key={row.perception} className="flex justify-between gap-4">
                <span>{row.label}</span>
                <span className="font-mono text-zinc-500">{row.conversionRate ?? "—"}%</span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
