"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { CallbackLoopMetrics, LoopOptimizationReport } from "@/lib/retention/loop-optimization";

function MetricCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        {hint ? <p className="mt-1 text-xs leading-relaxed text-zinc-600">{hint}</p> : null}
      </CardContent>
    </Card>
  );
}

function CallbackRow({ row }: { row: CallbackLoopMetrics }) {
  return (
    <li className="rounded-xl bg-white/[0.03] px-3 py-2">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="text-sm text-zinc-200">{row.noteText}</p>
        <span className="shrink-0 text-xs tabular-nums text-violet-300/90">weight {row.loopWeight}</span>
      </div>
      <p className="mt-1 text-xs text-zinc-500">
        {row.noteKind.replace(/_/g, " ")} · half-life {row.halfLifeScore} · residue {row.residueScore}
        {row.continuationScore > 0 ? ` · continuation ${row.continuationScore}%` : ""}
      </p>
      <p className="mt-1 text-xs tabular-nums text-zinc-600">
        {row.revisits} revisit{row.revisits === 1 ? "" : "s"} · {row.reflections} reflection
        {row.reflections === 1 ? "" : "s"} · {row.bookmarks} bookmark{row.bookmarks === 1 ? "" : "s"} ·{" "}
        {row.copies} cop{row.copies === 1 ? "y" : "ies"}
      </p>
    </li>
  );
}

function CallbackList({
  title,
  empty,
  rows,
  variant = "default",
}: {
  title: string;
  empty: string;
  rows: CallbackLoopMetrics[];
  variant?: "default" | "dead";
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          <ul className="space-y-2">
            {rows.map((row) =>
              variant === "dead" ? (
                <li key={row.noteId} className="rounded-xl bg-red-500/5 px-3 py-2 text-red-200/80">
                  <p className="text-sm">{row.noteText}</p>
                  <p className="mt-1 text-xs text-zinc-600">
                    {row.surfaces} surfaces · half-life {row.halfLifeScore} · no action
                  </p>
                </li>
              ) : (
                <CallbackRow key={row.noteId} row={row} />
              ),
            )}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function LoopOptimizationDebugPanel({ report }: { report: LoopOptimizationReport }) {
  return (
    <div className="space-y-6">
      <section className="grid gap-4 sm:grid-cols-3">
        <MetricCard label="Avg half-life" value={String(report.avgHalfLife)} hint="Action-backed callbacks decay slower" />
        <MetricCard label="Avg residue" value={String(report.avgResidue)} hint="Bookmarks, copies, revisits, reflections" />
        <MetricCard
          label="Continuation conversion"
          value={report.avgContinuationConversion}
          hint="Follow-up started → completed"
        />
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <CallbackList
          title="Top performing callbacks"
          empty="No action-backed callbacks yet."
          rows={report.topPerforming}
        />
        <CallbackList
          title="Dead callbacks"
          empty="No dead callbacks — surfaces without action."
          rows={report.deadCallbacks}
          variant="dead"
        />
        <CallbackList
          title="Callbacks causing revisits"
          empty="No revisit attribution yet."
          rows={report.causingRevisits}
        />
        <CallbackList
          title="Callbacks causing reflections"
          empty="No revisit → reflection chain yet."
          rows={report.causingReflections}
        />
        <CallbackList
          title="Callbacks causing bookmarks"
          empty="No bookmark attribution yet."
          rows={report.causingBookmarks}
        />
        <CallbackList
          title="Strongest copied-moment callbacks"
          empty="No copied moments linked to notes yet."
          rows={report.topCopied}
        />
      </div>

      {report.topContinuationPrompts.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-300">
              Follow-up prompts with highest continuation
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2">
              {report.topContinuationPrompts.map((row) => (
                <li key={row.promptId} className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm">
                  <p className="text-zinc-200">{row.noteText}</p>
                  <p className="mt-1 text-xs tabular-nums text-zinc-600">
                    {row.completed}/{row.started} completed · {row.conversionRate}
                  </p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      {report.noteTypesCausingReturn.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-300">Note types causing return</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.noteTypesCausingReturn.map((row) => (
                <li
                  key={row.kind}
                  className="flex flex-wrap items-baseline justify-between gap-2 rounded-xl bg-white/[0.03] px-3 py-2"
                >
                  <span className="text-zinc-200">{row.kind.replace(/_/g, " ")}</span>
                  <span className="text-xs tabular-nums text-zinc-600">
                    {row.revisitCount} revisit{row.revisitCount === 1 ? "" : "s"} · {row.reflectionCount}{" "}
                    reflection{row.reflectionCount === 1 ? "" : "s"} · {row.bookmarkCount} bookmark
                    {row.bookmarkCount === 1 ? "" : "s"}
                  </span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
