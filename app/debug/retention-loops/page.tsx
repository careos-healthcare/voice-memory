"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildRetentionLoopReport,
  clearRetentionLoopEvents,
  type RetentionLoopReport,
} from "@/lib/retention/retention-loops";
import {
  buildRevisitWorthReport,
  type RevisitWorthReport,
} from "@/lib/refinement/revisit-worth";
import {
  buildRevisitRhythmReport,
  type RevisitRhythmReport,
} from "@/lib/refinement/revisit-rhythm";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";

function ScoreCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">{hint}</p>
      </CardContent>
    </Card>
  );
}

export default function RetentionLoopsDebugPage() {
  const [report, setReport] = useState<RetentionLoopReport | null>(null);
  const [worthReport, setWorthReport] = useState<RevisitWorthReport | null>(null);
  const [rhythmReport, setRhythmReport] = useState<RevisitRhythmReport | null>(null);
  const [memoryEntries, setMemoryEntries] = useState<ReturnType<typeof getMemoryEligibleEntries>>([]);

  const refresh = () => {
    const entries = getMemoryEligibleEntries();
    setMemoryEntries(entries);
    setReport(buildRetentionLoopReport());
    setWorthReport(buildRevisitWorthReport(entries));
    setRhythmReport(buildRevisitRhythmReport(entries, "homepage"));
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Launch validation
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Retention loops
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local-only observation — whether resurfaced memories lead to voluntary returns,
              bookmarks, copies, and follow-up reflections. Not shown to users.
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <Button type="button" variant="ghost" size="sm" onClick={refresh}>
              <RefreshCw className="h-4 w-4" />
              Refresh
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => {
                clearRetentionLoopEvents();
                refresh();
              }}
            >
              Clear
            </Button>
          </div>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : !report.hasData ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              No loop events yet. Revisit an entry from a memory note, bookmark a reflection, or
              continue a follow-up prompt.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <ScoreCard
                label="Archive alive"
                value={`${report.scores.archiveAliveScore}`}
                hint="Revisits, clicks, bookmarks, copies, and returns weighted together."
              />
              <ScoreCard
                label="Revisit reward"
                value={`${report.scores.revisitRewardScore}%`}
                hint="Memory note clicks that led to a reward within 7 days."
              />
              <ScoreCard
                label="Follow-up continuation"
                value={`${report.scores.followUpContinuationScore}%`}
                hint="Follow-up prompts started that became new recordings."
              />
            </div>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-base">Return indicators</CardTitle>
              </CardHeader>
              <CardContent className="text-sm text-zinc-400">
                <p>
                  Day 1 returns:{" "}
                  <span className="font-medium text-white">{report.returnIndicators.day1Count}</span>
                </p>
                <p className="mt-1">
                  Within 7 days:{" "}
                  <span className="font-medium text-white">{report.returnIndicators.day7Count}</span>
                </p>
              </CardContent>
            </Card>

            <Section
              title="Memory notes that caused revisits"
              empty="No note-driven revisits yet."
              items={report.notesCausingRevisits.map((row) => (
                <Row
                  key={row.noteId}
                  title={row.noteText}
                  meta={`${row.clicks} clicks · ${row.oldEntryOpens} older opens · ${row.bookmarks} bookmarks · ${row.copies} copies · ${row.day1Returns} day-1 · ${row.day7Returns} day-7`}
                />
              ))}
            />

            <Section
              title="Revisits that caused new reflections"
              empty="No revisit → reflection chain yet."
              items={report.revisitsCausingReflections.map((row) => (
                <Row
                  key={`${row.entryId}-${row.revisitedAt}`}
                  title={`Entry ${row.entryId.slice(0, 8)}…`}
                  meta={
                    row.reflectionEntryId
                      ? `New reflection ${row.reflectionEntryId.slice(0, 8)}… · ${row.sources}`
                      : `No new reflection yet · ${row.sources}`
                  }
                />
              ))}
            />

            <Section
              title="Callbacks that caused bookmarks"
              empty="No bookmark attribution yet."
              items={report.callbacksCausingBookmarks.map((row) => (
                <Row
                  key={row.noteId}
                  title={row.noteText}
                  meta={`${row.bookmarkCount} bookmark${row.bookmarkCount === 1 ? "" : "s"}`}
                />
              ))}
            />

            <Section
              title="Copied moments by note"
              empty="No copied moments linked to notes yet."
              items={report.copiedMomentsByNote.map((row) => (
                <Row
                  key={row.noteId}
                  title={row.noteText}
                  meta={`${row.count} cop${row.count === 1 ? "y" : "ies"}`}
                />
              ))}
            />

            <Section
              title="Recent loop events"
              empty="No events."
              items={report.events.slice(0, 24).map((event) => (
                <Row
                  key={event.id}
                  title={event.kind.replace(/_/g, " ")}
                  meta={[
                    event.noteText ?? event.noteId,
                    event.entryId ?? event.targetEntryId ?? event.pastEntryId,
                    new Date(event.at).toLocaleString(),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                />
              ))}
            />

            <Section
              title="Worth revisiting (internal pool)"
              empty="No emotionally worth-reopening entries yet."
              items={(worthReport?.entries ?? []).map((row) => {
                const entry = memoryEntries.find((e) => e.id === row.entryId);
                const signalSummary = row.signals
                  .map((signal) => `${signal.id} +${signal.points}`)
                  .join(" · ");
                return (
                  <Row
                    key={row.entryId}
                    title={
                      entry
                        ? `${formatEntryDate(entry.createdAt)} · score ${row.total}`
                        : `${row.entryId.slice(0, 8)}… · score ${row.total}`
                    }
                    meta={signalSummary || "No signals"}
                  />
                );
              })}
            />

            <Section
              title="Revisit rhythm (internal pool)"
              empty="No revisit rhythm signals yet."
              items={(rhythmReport?.candidates ?? []).map((row) => (
                <Row
                  key={row.id}
                  title={`${row.text} · score ${row.strength}`}
                  meta={[row.kind, row.entryId?.slice(0, 8)].filter(Boolean).join(" · ")}
                />
              ))}
            />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/moat" className="text-violet-300 hover:text-violet-200">
            Moat metrics →
          </Link>
          <Link href="/debug/retention" className="text-violet-300 hover:text-violet-200">
            Retention overview →
          </Link>
          <Link href="/debug/callbacks" className="text-violet-300 hover:text-violet-200">
            Callback quality →
          </Link>
          <Link href="/launch" className="text-zinc-500 hover:text-zinc-300">
            Launch checklist →
          </Link>
        </div>
      </div>
    </div>
  );
}

function Section({
  title,
  empty,
  items,
}: {
  title: string;
  empty: string;
  items: React.ReactNode[];
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        {items.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          items
        )}
      </CardContent>
    </Card>
  );
}

function Row({ title, meta }: { title: string; meta: string }) {
  return (
    <div className="rounded-xl bg-white/[0.03] px-3 py-2">
      <p className="text-sm text-zinc-200">{title}</p>
      <p className="mt-1 text-xs text-zinc-500">{meta}</p>
    </div>
  );
}
