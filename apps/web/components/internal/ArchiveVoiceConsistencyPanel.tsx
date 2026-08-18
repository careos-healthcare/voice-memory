import type { ArchiveVoiceConsistencyReport } from "@/types/archive-voice";

interface ArchiveVoiceConsistencyPanelProps {
  report: ArchiveVoiceConsistencyReport;
}

export function ArchiveVoiceConsistencyPanel({
  report,
}: ArchiveVoiceConsistencyPanelProps) {
  return (
    <section className="space-y-6">
      <div className="rounded-2xl border border-white/10 bg-zinc-900/30 p-6">
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">Copy audit</p>
        <h2 className="mt-2 text-lg font-semibold text-white">{report.title}</h2>
        <p className="mt-2 text-sm text-zinc-400">
          Scans blind spots, discover, theories, updates, and archive value surfaces for coaching,
          motivational, and therapy language.
        </p>
        <p
          className={`mt-3 text-sm font-medium ${report.pass ? "text-emerald-400/90" : "text-amber-400/90"}`}
        >
          {report.pass ? "Pass" : "Needs review"} — {report.totalViolations} violation
          {report.totalViolations === 1 ? "" : "s"}
        </p>
        <ul className="mt-4 space-y-1 text-sm text-zinc-500">
          {report.summaryLines.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </div>

      <div className="space-y-4">
        {report.scopes.map((scope) => (
          <div
            key={scope.id}
            className="rounded-xl border border-white/5 bg-black/20 px-4 py-4"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="text-sm font-medium text-zinc-200">{scope.label}</h3>
              <span className="text-xs text-zinc-600">
                {scope.filesScanned} files · {scope.violations.length} violations
              </span>
            </div>
            {scope.preferredSignalsFound.length > 0 ? (
              <p className="mt-2 text-xs text-zinc-600">
                Signals: {scope.preferredSignalsFound.join(", ")}
              </p>
            ) : null}
            {scope.violations.length > 0 ? (
              <ul className="mt-3 space-y-2">
                {scope.violations.map((v, i) => (
                  <li
                    key={`${v.file}-${v.line}-${i}`}
                    className="rounded-lg border border-amber-500/20 bg-amber-950/20 px-3 py-2 text-xs text-amber-100/90"
                  >
                    <span className="font-medium uppercase tracking-wide text-amber-300/80">
                      {v.category}
                    </span>
                    <span className="text-zinc-500"> · {v.file}:{v.line}</span>
                    <p className="mt-1 text-zinc-400">
                      “{v.match}” — {v.excerpt}
                    </p>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-xs text-zinc-600">No flagged lines.</p>
            )}
          </div>
        ))}
      </div>

      <div className="rounded-xl border border-dashed border-white/10 px-4 py-4 text-xs text-zinc-600">
        <p className="font-medium text-zinc-500">Preferred archive voice</p>
        <ul className="mt-2 list-inside list-disc space-y-1">
          <li>Your archive is still evaluating this.</li>
          <li>New evidence may support this theory.</li>
          <li>This theory may be changing.</li>
          <li>Recent reflections point in a different direction.</li>
        </ul>
        <p className="mt-3 font-medium text-zinc-500">Avoid</p>
        <p className="mt-1">
          Great job · You are growing · You should · Keep going · Proud of you · Healing ·
          Transformation
        </p>
        <p className="mt-3 text-zinc-700">
          CI: <code className="text-zinc-500">npm run validate:archive-voice</code>
        </p>
      </div>
    </section>
  );
}
