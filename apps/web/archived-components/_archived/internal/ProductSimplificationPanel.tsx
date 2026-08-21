"use client";

import { buildProductSimplificationReport } from "@/lib/internal/product-simplification-report";
import { buildSurfaceAuditReport } from "@/lib/product/surface-audit";

export function ProductSimplificationPanel() {
  const report = buildProductSimplificationReport();
  const audit = buildSurfaceAuditReport();

  return (
    <section className="space-y-6">
      <div className="rounded-2xl border border-violet-500/25 bg-violet-950/10 p-6">
        <p className="text-xs uppercase tracking-wider text-violet-300/80">One-liner test</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-200">{report.oneLiner}</p>
      </div>

      <dl className="grid gap-4 sm:grid-cols-3">
        <Stat label="Visible concepts (legacy)" value={report.currentConceptCount} />
        <Stat label="Target concepts" value={report.targetConceptCount} />
        <Stat label="Simplification score" value={`${report.simplificationScore}%`} />
      </dl>

      <p className="text-sm text-zinc-400">{report.recommendation}</p>

      <div className="overflow-x-auto rounded-xl border border-white/10">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-white/10 text-xs uppercase text-zinc-500">
              <th className="px-4 py-2">Concept</th>
              <th className="px-4 py-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {report.conceptRows.map((row) => (
              <tr key={row.concept} className="border-b border-white/5 text-zinc-400">
                <td className="px-4 py-2">{row.concept}</td>
                <td className="px-4 py-2">{row.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="rounded-xl border border-white/10 px-4 py-4">
        <p className="text-xs uppercase text-zinc-500">Surface audit</p>
        <pre className="mt-3 whitespace-pre-wrap text-xs text-zinc-500">
          {audit.lines.join("\n")}
        </pre>
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-white/10 px-4 py-3">
      <dt className="text-xs text-zinc-500">{label}</dt>
      <dd className="mt-1 text-xl font-semibold text-white">{value}</dd>
    </div>
  );
}
