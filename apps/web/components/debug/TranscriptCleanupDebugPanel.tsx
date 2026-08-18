"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { TranscriptCleanupDebugReport } from "@/lib/debug/transcript-cleanup-review";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function CleanupResultBlock({
  title,
  raw,
  cleaned,
  result,
}: {
  title: string;
  raw: string;
  cleaned: string;
  result: TranscriptCleanupDebugReport["fixtures"][number]["result"];
}) {
  return (
    <div className="border-b border-white/5 py-4 text-sm last:border-b-0">
      <p className="text-zinc-200">{title}</p>
      <p className="mt-2 text-xs uppercase tracking-wide text-zinc-600">Raw</p>
      <p className="mt-1 text-zinc-400">{raw}</p>
      <p className="mt-3 text-xs uppercase tracking-wide text-zinc-600">Cleaned</p>
      <p className="mt-1 text-zinc-300">{cleaned}</p>
      <p className="mt-3 text-xs text-zinc-500">
        Internal {result.confidence} · fillers {result.removedFillers.length} · repetitions{" "}
        {result.collapsedRepetitions.length}
      </p>
      {result.preservedPhrases.length > 0 ? (
        <p className="mt-2 text-xs text-violet-300/80">
          Preserved: {result.preservedPhrases.map((phrase) => phrase.text).join(" · ")}
        </p>
      ) : null}
      {result.removedFillers.length > 0 ? (
        <p className="mt-1 text-xs text-zinc-600">
          Removed fillers: {result.removedFillers.join(", ")}
        </p>
      ) : null}
      {result.collapsedRepetitions.length > 0 ? (
        <p className="mt-1 text-xs text-zinc-600">
          Collapsed:{" "}
          {result.collapsedRepetitions
            .map((item) => `"${item.original}" → "${item.collapsed}"`)
            .join(" · ")}
        </p>
      ) : null}
      {result.cleanupWarnings.length > 0 ? (
        <p className="mt-2 text-xs text-amber-400/90">
          Warnings: {result.cleanupWarnings.join(" · ")}
        </p>
      ) : null}
    </div>
  );
}

export function TranscriptCleanupDebugPanel({
  report,
}: {
  report: TranscriptCleanupDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Fixture examples" value={String(report.fixtures.length)} />
          <Row label="Recent entries reviewed" value={String(report.entries.length)} />
          <Row label="Entries with raw transcript" value={String(report.totals.entriesWithRaw)} />
          <Row
            label="Entries with cleanup metadata"
            value={String(report.totals.entriesWithCleanupMeta)}
          />
          <Row label="Low-confidence cleanups" value={String(report.totals.lowConfidence)} />
          <Row
            label="Preserved phrases (recent sample)"
            value={String(report.totals.preservedPhraseCount)}
          />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Fixture examples</CardTitle>
        </CardHeader>
        <CardContent>
          {report.fixtures.map((fixture) => (
            <CleanupResultBlock
              key={fixture.label}
              title={fixture.label}
              raw={fixture.raw}
              cleaned={fixture.result.cleanedTranscript}
              result={fixture.result}
            />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent entries</CardTitle>
        </CardHeader>
        <CardContent>
          {report.entries.length === 0 ? (
            <p className="text-sm text-zinc-500">No entries in local data yet.</p>
          ) : (
            report.entries.map((entry) => (
              <CleanupResultBlock
                key={entry.entryId}
                title={`${entry.entryId.slice(0, 8)}… · ${entry.createdAt.slice(0, 16)}`}
                raw={entry.rawTranscript}
                cleaned={entry.cleanedTranscript}
                result={entry.result}
              />
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
