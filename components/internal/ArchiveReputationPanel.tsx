"use client";

import { buildArchiveReputationReport } from "@/lib/internal/archive-reputation-report";
import { ARCHIVE_REPUTATION_LEVEL_LABEL } from "@/lib/archive/archive-reputation-copy";

export function ArchiveReputationPanel() {
  const report = buildArchiveReputationReport();

  return (
    <div className="space-y-6 rounded-2xl border border-white/10 bg-zinc-900/40 p-5">
      <div>
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Reputation</p>
        <p className="mt-2 text-sm text-zinc-400">
          Current:{" "}
          {report.currentLevel
            ? ARCHIVE_REPUTATION_LEVEL_LABEL[report.currentLevel]
            : "—"}
        </p>
        {report.currentSummary ? (
          <p className="mt-1 text-sm text-zinc-500">{report.currentSummary}</p>
        ) : null}
      </div>

      <div>
        <h2 className="text-sm font-medium text-zinc-300">Critical questions</h2>
        <ul className="mt-2 space-y-1 text-sm text-zinc-500">
          {report.criticalQuestions.map((q) => (
            <li key={q}>— {q}</li>
          ))}
        </ul>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs text-zinc-400">
          <thead>
            <tr className="border-b border-white/10 text-zinc-500">
              <th className="py-2 pr-4">Level</th>
              <th className="py-2 pr-4">Return</th>
              <th className="py-2 pr-4">Attachment</th>
              <th className="py-2 pr-4">Conversion</th>
              <th className="py-2">Recall</th>
            </tr>
          </thead>
          <tbody>
            {report.byLevel.map((row) => (
              <tr key={row.level} className="border-b border-white/5">
                <td className="py-2 pr-4 text-zinc-300">{row.label}</td>
                <td className="py-2 pr-4 tabular-nums">
                  {row.returnRate !== null ? `${row.returnRate}%` : "—"}
                </td>
                <td className="py-2 pr-4 tabular-nums">
                  {row.attachmentRate !== null ? `${row.attachmentRate}%` : "—"}
                </td>
                <td className="py-2 pr-4 tabular-nums">
                  {row.conversionRate !== null ? `${row.conversionRate}%` : "—"}
                </td>
                <td className="py-2 tabular-nums">
                  {row.recallRate !== null ? `${row.recallRate}%` : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <ul className="space-y-1 text-xs text-zinc-600">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </div>
  );
}
