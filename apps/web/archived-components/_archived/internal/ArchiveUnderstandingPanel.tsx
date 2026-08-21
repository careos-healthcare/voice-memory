"use client";

import { useMemo } from "react";

import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  ARCHIVE_UNDERSTANDING_PROMPT,
  buildArchiveUnderstandingValidationReport,
} from "@/lib/founder-test/archive-understanding-validation";
import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";

export function ArchiveUnderstandingPanel() {
  const report = useMemo(
    () => buildArchiveUnderstandingValidationReport(readFounderTestRecords()),
    [],
  );

  return (
    <Card className="border-sky-500/20 bg-sky-950/10" data-testid="archive-understanding-panel">
      <CardContent className="space-y-4 pt-6">
        <p className="text-sm font-medium text-sky-100">Instant understanding — founder check</p>
        <p className="text-sm leading-relaxed text-zinc-300">{ARCHIVE_UNDERSTANDING_PROMPT}</p>
        <ul className="space-y-1 text-sm text-zinc-400">
          {report.lines.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
        {report.verbatims.length > 0 ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">
              Verbatim responses
            </p>
            <ul className="mt-2 space-y-2 text-sm text-zinc-400">
              {report.verbatims.map((quote, i) => (
                <li key={`${i}-${quote.slice(0, 24)}`} className="rounded-lg bg-black/25 px-3 py-2">
                  &ldquo;{quote}&rdquo;
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
