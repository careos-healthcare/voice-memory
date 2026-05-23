import type { PrintableReport } from "@/lib/memory-export";

interface PrintReportDocumentProps {
  report: PrintableReport;
}

function formatGeneratedAt(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "long",
    timeStyle: "short",
  }).format(new Date(iso));
}

export function PrintReportDocument({ report }: PrintReportDocumentProps) {
  return (
    <article className="print-report mx-auto max-w-[48rem] px-8 py-10 text-[11pt] leading-relaxed text-zinc-900">
      <header className="border-b border-zinc-300 pb-6">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-violet-700">
          VoiceMemory
        </p>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-900">
          Reflection report
        </h1>
        <p className="mt-2 text-sm text-zinc-600">
          Generated {formatGeneratedAt(report.generatedAt)} · {report.dateRangeLabel}
        </p>
        <p className="mt-3 text-xs text-zinc-500">
          Reflective mirror only — not therapy, not medical advice, no diagnosis.
          Exported from your device; nothing stored on a server.
        </p>
      </header>

      <section className="mt-8">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-700">
          Weekly summary
        </h2>
        <p className="mt-1 text-xs text-zinc-500">{report.weekRangeLabel}</p>
        <p className="mt-3 text-sm text-zinc-800">{report.weeklySummary}</p>
      </section>

      {report.moodTimeline.length > 0 ? (
        <section className="mt-8 break-inside-avoid">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-700">
            Mood timeline
          </h2>
          <table className="mt-3 w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-zinc-300 text-left text-xs text-zinc-600">
                <th className="py-2 pr-4">Day</th>
                <th className="py-2 pr-4">Avg intensity</th>
                <th className="py-2">Entries</th>
              </tr>
            </thead>
            <tbody>
              {report.moodTimeline.map((row) => (
                <tr key={row.label} className="border-b border-zinc-200">
                  <td className="py-2 pr-4">{row.label}</td>
                  <td className="py-2 pr-4">{row.avgIntensity}/10</td>
                  <td className="py-2">{row.entryCount}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ) : null}

      {report.recurringThemes.length > 0 ? (
        <section className="mt-8 break-inside-avoid">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-700">
            Recurring themes
          </h2>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm">
            {report.recurringThemes.map((t) => (
              <li key={t.theme}>
                <span className="capitalize">{t.theme}</span> — {t.count}×
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {report.recurringEntities.length > 0 ? (
        <section className="mt-8 break-inside-avoid">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-700">
            Recurring entities
          </h2>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm">
            {report.recurringEntities.map((e) => (
              <li key={`${e.type}-${e.name}`}>
                <span className="capitalize">{e.name}</span> ({e.type}) — {e.count}×
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="mt-8">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-700">
          Entry excerpts
        </h2>
        <p className="mt-1 text-xs text-zinc-500">
          Showing {report.entryExcerpts.length} of {report.totalEntries} entries in range
        </p>
        <div className="mt-4 space-y-6">
          {report.entryExcerpts.map((entry) => (
            <div
              key={entry.id}
              className="break-inside-avoid rounded-lg border border-zinc-200 p-4"
            >
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <p className="text-sm font-semibold capitalize text-zinc-900">
                  {entry.mood} · {entry.intensity}/10
                </p>
                <p className="text-xs text-zinc-500">{entry.dateLabel}</p>
              </div>
              {entry.themes.length > 0 ? (
                <p className="mt-1 text-xs text-zinc-600">
                  Themes: {entry.themes.join(", ")}
                </p>
              ) : null}
              <p className="mt-3 text-sm font-medium text-zinc-800">Observation</p>
              <p className="mt-1 text-sm text-zinc-700">{entry.observation}</p>
              {entry.excerpt ? (
                <>
                  <p className="mt-3 text-sm font-medium text-zinc-800">Transcript excerpt</p>
                  <p className="mt-1 text-sm italic text-zinc-600">{entry.excerpt}</p>
                </>
              ) : null}
            </div>
          ))}
        </div>
      </section>

      <footer className="mt-10 border-t border-zinc-300 pt-4 text-xs text-zinc-500">
        VoiceMemory · Private export · {report.totalEntries} total entries in selected range
      </footer>
    </article>
  );
}
