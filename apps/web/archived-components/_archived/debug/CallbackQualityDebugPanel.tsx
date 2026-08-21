"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  getCallbackReviewLabels,
  toggleCallbackReviewLabel,
} from "@/lib/debug/callback-review-labels";
import {
  CALLBACK_REVIEW_FILTERS,
  matchesCallbackFilter,
  type CallbackReviewFilter,
} from "@/lib/debug/callback-quality-score";
import { downloadCallbackReviewJson, downloadCallbackSurvivalJson } from "@/lib/debug/callback-review-export";
import {
  downloadCallbackPruningJson,
  getCallbackPruningAction,
  PRUNING_ACTION_LABELS,
  setCallbackPruningAction,
} from "@/lib/debug/callback-pruning";
import {
  CALLBACK_REVIEW_LABELS,
  REWRITE_FLAG_LABELS,
  type CallbackQualityReviewReport,
  type CallbackReviewItem,
  type CallbackReviewLabel,
} from "@/types/callback-quality-review";
import type { CallbackPruningAction } from "@/types/observation-workflow";

function SignalRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 text-xs">
      <span className="text-zinc-500">{label}</span>
      <span className="tabular-nums text-zinc-300">{value}</span>
    </div>
  );
}

function survivalDots(item: CallbackReviewItem): string {
  const marks: string[] = [];
  const s = item.survival;
  if (s.remembered24hFlag || s.remembered24hManual) marks.push("24h");
  if (s.remembered72hFlag || s.remembered72hManual) marks.push("72h");
  if (s.oldEntryRevisitCount > 0) marks.push("↩");
  if (s.followUpCompleteCount > 0) marks.push("→");
  if (s.bookmarkAfterCallbackCount > 0) marks.push("★");
  if (s.copiedMemoryMomentCount > 0) marks.push("⎘");
  return marks.join(" ") || "—";
}

function engagementDots(item: CallbackReviewItem): string {
  const marks: string[] = [];
  if (item.retention.reread > 0 || item.signals.rereadCount > 0) marks.push("↻");
  if (item.retention.revisit > 0 || item.signals.revisitCount > 0) marks.push("↩");
  if (item.retention.bookmark > 0 || item.signals.bookmarked) marks.push("★");
  if (item.retention.copied > 0 || item.signals.memoryMomentCopied) marks.push("⎘");
  if (item.continuedFollowup || item.retention.recording > 0) marks.push("→");
  return marks.join(" ") || "—";
}

function CallbackRankedTable({
  items,
  selectedId,
  onSelect,
}: {
  items: CallbackReviewItem[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-xl border border-white/5">
      <table className="w-full min-w-[720px] text-left text-sm">
        <thead>
          <tr className="border-b border-white/5 text-[10px] uppercase tracking-wider text-zinc-600">
            <th className="px-3 py-2.5 font-medium">#</th>
            <th className="px-3 py-2.5 font-medium">Line</th>
            <th className="px-3 py-2.5 font-medium">Residue</th>
            <th className="px-3 py-2.5 font-medium">Survival</th>
            <th className="px-3 py-2.5 font-medium">Pause</th>
            <th className="px-3 py-2.5 font-medium">Quality</th>
            <th className="px-3 py-2.5 font-medium">Engagement</th>
            <th className="px-3 py-2.5 font-medium">Survived</th>
            <th className="px-3 py-2.5 font-medium">Flags</th>
            <th className="px-3 py-2.5 font-medium">Source</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item, index) => (
            <tr
              key={`${item.kind}-${item.id}`}
              className={`cursor-pointer border-b border-white/[0.03] transition-colors hover:bg-white/[0.03] ${
                selectedId === item.id ? "bg-violet-500/10" : ""
              }`}
              onClick={() => onSelect(item.id)}
            >
              <td className="px-3 py-3 tabular-nums text-zinc-600">{index + 1}</td>
              <td className="max-w-xs px-3 py-3">
                <p className="line-clamp-2 leading-relaxed text-zinc-200">{item.text}</p>
                <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                  {item.kind.replace(/_/g, " ")}
                </p>
              </td>
              <td className="px-3 py-3 tabular-nums font-medium text-violet-200">
                {item.emotionalResidueScore}
              </td>
              <td className="px-3 py-3 tabular-nums font-medium text-sky-200">
                {item.survival.emotionalSurvivalScore}
              </td>
              <td className="px-3 py-3 tabular-nums font-medium text-amber-200/90">
                {item.pause.pauseScore}
              </td>
              <td className="px-3 py-3 tabular-nums text-zinc-400">{item.qualityScore}</td>
              <td className="px-3 py-3 text-xs text-zinc-500">{engagementDots(item)}</td>
              <td className="px-3 py-3 text-xs text-zinc-500">{survivalDots(item)}</td>
              <td className="px-3 py-3">
                <div className="flex flex-wrap gap-1">
                  {item.pause.highDwellLowAction ? (
                    <span className="rounded-full bg-yellow-500/10 px-1.5 py-0.5 text-[10px] text-yellow-200/90">
                      High dwell
                    </span>
                  ) : null}
                  {item.pause.causedAudioReplay ? (
                    <span className="rounded-full bg-indigo-500/10 px-1.5 py-0.5 text-[10px] text-indigo-200/90">
                      Replay
                    </span>
                  ) : null}
                  {item.survival.lowSurvivalCutCandidate ? (
                    <span className="rounded-full bg-orange-500/10 px-1.5 py-0.5 text-[10px] text-orange-200/90">
                      Low survival
                    </span>
                  ) : null}
                  {item.doubleDown ? (
                    <span className="rounded-full bg-emerald-500/10 px-1.5 py-0.5 text-[10px] text-emerald-200/90">
                      Double down
                    </span>
                  ) : null}
                  {item.cutCandidate ? (
                    <span className="rounded-full bg-rose-500/10 px-1.5 py-0.5 text-[10px] text-rose-200/90">
                      Cut
                    </span>
                  ) : null}
                  {item.rewriteFlags.length > 0 ? (
                    <span className="rounded-full bg-amber-500/10 px-1.5 py-0.5 text-[10px] text-amber-200/90">
                      Rewrite
                    </span>
                  ) : null}
                </div>
              </td>
              <td className="px-3 py-3">
                <p className="font-mono text-[10px] leading-relaxed text-zinc-500">
                  {item.sourceLocation.file.replace("lib/", "")}
                </p>
                <p className="font-mono text-[10px] text-zinc-600">
                  {item.sourceLocation.function}()
                </p>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CallbackReviewCard({
  item,
  onLabelsChange,
}: {
  item: CallbackReviewItem;
  onLabelsChange: () => void;
}) {
  const [labels, setLabels] = useState<CallbackReviewLabel[]>(() =>
    getCallbackReviewLabels(item.id),
  );
  const [pruningAction, setPruningAction] = useState<CallbackPruningAction | null>(() =>
    getCallbackPruningAction(item.id),
  );

  const toggleLabel = (label: CallbackReviewLabel) => {
    const next = toggleCallbackReviewLabel(item.id, label);
    setLabels(next);
    onLabelsChange();
  };

  const choosePruningAction = (action: CallbackPruningAction) => {
    setCallbackPruningAction(item.id, action, item.text);
    setPruningAction(action);
    onLabelsChange();
  };

  return (
    <Card
      id={`callback-${item.id}`}
      className={
        item.cutCandidate
          ? "border-rose-500/20"
          : item.doubleDown
            ? "border-emerald-500/20"
            : item.rewriteFlags.length > 0
              ? "border-amber-500/25"
              : undefined
      }
    >
      <CardHeader className="space-y-3 pb-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500">
            {item.kind.replace(/_/g, " ")}
          </span>
          {item.doubleDown ? (
            <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] text-emerald-200/90">
              Double down
            </span>
          ) : null}
          {item.cutCandidate ? (
            <span className="rounded-full bg-rose-500/10 px-2 py-0.5 text-[10px] text-rose-200/90">
              Cut candidate
            </span>
          ) : null}
          {item.rewriteFlags.length > 0 ? (
            <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-[10px] text-amber-200/90">
              Rewrite candidate
            </span>
          ) : null}
          <span className="text-[10px] tabular-nums text-zinc-600">
            residue {item.emotionalResidueScore} · survival {item.survival.emotionalSurvivalScore} ·
            pause {item.pause.pauseScore} · quality {item.qualityScore}
          </span>
        </div>
        <CardTitle className="text-base font-normal leading-relaxed text-zinc-200">
          {item.text}
        </CardTitle>
        <p className="text-xs leading-relaxed text-zinc-500">
          Surfaces: {item.surfaces.join(", ")}
        </p>
        <p className="font-mono text-[10px] leading-relaxed text-zinc-600">
          {item.sourceLocation.file} → {item.sourceLocation.function}()
          {item.sourceLocation.note ? ` (${item.sourceLocation.note})` : ""}
        </p>
      </CardHeader>

      <CardContent className="space-y-5 border-t border-white/5 pt-4">
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Why it surfaced
          </p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.whySurfaced}</p>
        </div>

        {(item.beforeQuote || item.afterQuote) && (
          <div className="grid gap-3 sm:grid-cols-2">
            {item.beforeQuote ? (
              <div className="rounded-xl bg-white/[0.03] p-3">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">Before</p>
                {item.beforeDateLabel ? (
                  <p className="mt-1 text-[10px] text-zinc-600">{item.beforeDateLabel}</p>
                ) : null}
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.beforeQuote}</p>
              </div>
            ) : null}
            {item.afterQuote ? (
              <div className="rounded-xl bg-white/[0.03] p-3">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">After</p>
                {item.afterDateLabel ? (
                  <p className="mt-1 text-[10px] text-zinc-600">{item.afterDateLabel}</p>
                ) : null}
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.afterQuote}</p>
              </div>
            ) : null}
          </div>
        )}

        {item.sourceEntries.length > 0 ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Source entries
            </p>
            <ul className="mt-2 space-y-2">
              {item.sourceEntries.map((entry) => (
                <li key={entry.id} className="rounded-xl bg-white/[0.03] px-3 py-2">
                  <Link href={entry.href} className="text-sm text-violet-300 hover:text-violet-200">
                    {entry.dateLabel}
                  </Link>
                  {entry.snippet ? (
                    <p className="mt-1 text-xs leading-relaxed text-zinc-500">{entry.snippet}</p>
                  ) : null}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Pause moment analysis
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Pause score" value={String(item.pause.pauseScore)} />
            <SignalRow
              label="Emotional interruption"
              value={String(item.pause.emotionalInterruptionScore)}
            />
            <SignalRow label="Reread likelihood" value={String(item.pause.rereadLikelihood)} />
            <SignalRow label="Replay likelihood" value={String(item.pause.replayLikelihood)} />
            <SignalRow
              label="Dwell after callback"
              value={`${Math.round(item.pause.dwellAfterCallbackMs / 1000)}s`}
            />
            <SignalRow label="Scroll pauses" value={String(item.pause.scrollPauseCount)} />
            <SignalRow label="Audio replays" value={String(item.pause.audioReplayCount)} />
            <SignalRow
              label="Old-entry revisits"
              value={String(item.pause.oldEntryRevisitCount)}
            />
            <SignalRow label="Bookmarks" value={String(item.pause.bookmarkCount)} />
            <SignalRow label="Copies" value={String(item.pause.copyCount)} />
            <SignalRow label="Follow-ups" value={String(item.pause.followUpCount)} />
            <SignalRow
              label="High dwell, low action"
              value={item.pause.highDwellLowAction ? "yes" : "no"}
            />
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Survival analysis
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Shown" value={String(item.survival.callbackShownCount)} />
            <SignalRow label="Rereads" value={String(item.survival.rereadCount)} />
            <SignalRow
              label="Old-entry revisits"
              value={String(item.survival.oldEntryRevisitCount)}
            />
            <SignalRow
              label="Bookmarks after callback"
              value={String(item.survival.bookmarkAfterCallbackCount)}
            />
            <SignalRow
              label="Copied memory moments"
              value={String(item.survival.copiedMemoryMomentCount)}
            />
            <SignalRow
              label="Follow-up starts"
              value={String(item.survival.followUpStartCount)}
            />
            <SignalRow
              label="Follow-up completes"
              value={String(item.survival.followUpCompleteCount)}
            />
            <SignalRow
              label="Dwell average"
              value={`${Math.round(item.survival.dwellTimeAverageMs / 1000)}s`}
            />
            <SignalRow
              label="Remembered 24h"
              value={
                item.survival.remembered24hFlag || item.survival.remembered24hManual
                  ? item.survival.remembered24hManual
                    ? "manual"
                    : "flag"
                  : "no"
              }
            />
            <SignalRow
              label="Remembered 72h"
              value={
                item.survival.remembered72hFlag || item.survival.remembered72hManual
                  ? item.survival.remembered72hManual
                    ? "manual"
                    : "flag"
                  : "no"
              }
            />
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Survival scores
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Pause" value={String(item.survival.pauseScore)} />
            <SignalRow label="Revisit" value={String(item.survival.revisitScore)} />
            <SignalRow label="Continuation" value={String(item.survival.continuationScore)} />
            <SignalRow label="Remembered" value={String(item.survival.rememberedScore)} />
            <SignalRow
              label="Emotional survival"
              value={String(item.survival.emotionalSurvivalScore)}
            />
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Retention observation
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Surfaced" value={String(item.retention.surfaced)} />
            <SignalRow label="Ignored" value={String(item.retention.ignored)} />
            <SignalRow label="Rereads" value={String(item.retention.reread)} />
            <SignalRow label="Revisits" value={String(item.retention.revisit)} />
            <SignalRow label="New recordings" value={String(item.retention.recording)} />
            <SignalRow label="Bookmarked" value={String(item.retention.bookmark)} />
            <SignalRow label="Copied / shared" value={String(item.retention.copied)} />
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Interaction signals
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Rereads" value={String(item.signals.rereadCount)} />
            <SignalRow label="Revisited entries" value={String(item.signals.revisitCount)} />
            <SignalRow label="Bookmarked" value={item.signals.bookmarked ? "yes" : "no"} />
            <SignalRow
              label="Memory moment copied"
              value={item.signals.memoryMomentCopied ? "yes" : "no"}
            />
            <SignalRow label="Dwell time" value={`${Math.round(item.signals.dwellMs / 1000)}s`} />
            <SignalRow
              label="Continued follow-up"
              value={item.continuedFollowup ? "yes" : "no"}
            />
          </div>
        </div>

        {item.followupPrompt ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Follow-up prompt
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-500">{item.followupPrompt}</p>
          </div>
        ) : null}

        {item.rewriteFlags.length > 0 ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Rewrite flags
            </p>
            <ul className="mt-2 flex flex-wrap gap-2">
              {item.rewriteFlags.map((flag) => (
                <li
                  key={flag}
                  className="rounded-full bg-amber-500/10 px-2 py-1 text-[10px] text-amber-100/90"
                >
                  {REWRITE_FLAG_LABELS[flag]}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Manual review
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {CALLBACK_REVIEW_LABELS.map(({ value, label }) => {
              const active = labels.includes(value);
              return (
                <Button
                  key={value}
                  type="button"
                  size="sm"
                  variant={active ? "default" : "secondary"}
                  className="h-auto px-2 py-1 text-[11px]"
                  onClick={() => toggleLabel(value)}
                >
                  {label}
                </Button>
              );
            })}
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Pruning decision
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {(Object.keys(PRUNING_ACTION_LABELS) as CallbackPruningAction[]).map((action) => {
              const active = pruningAction === action;
              return (
                <Button
                  key={action}
                  type="button"
                  size="sm"
                  variant={active ? "default" : "secondary"}
                  className="h-auto px-2 py-1 text-[11px]"
                  onClick={() => choosePruningAction(action)}
                >
                  {PRUNING_ACTION_LABELS[action]}
                </Button>
              );
            })}
          </div>
          {pruningAction ? (
            <p className="mt-2 text-xs text-zinc-500">
              Saved locally: {PRUNING_ACTION_LABELS[pruningAction]}
            </p>
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}

export function CallbackQualityDebugPanel({
  report,
  onRefresh,
}: {
  report: CallbackQualityReviewReport;
  onRefresh: () => void;
}) {
  const [filter, setFilter] = useState<CallbackReviewFilter>("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [, bump] = useState(0);

  const items = useMemo(() => {
    return report.items.filter((item) =>
      matchesCallbackFilter(item, filter, item.manualLabels),
    );
  }, [filter, report.items]);

  const handleSelect = (id: string) => {
    setSelectedId(id);
    requestAnimationFrame(() => {
      document.getElementById(`callback-${id}`)?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="grid flex-1 grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-10">
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Callbacks
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-white">
                {report.items.length}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Double down
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-emerald-300">
                {report.doubleDownCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Cut candidates
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-rose-300">
                {report.cutCandidateCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Labeled
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-white">
                {report.labeledCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Rewrite
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-white">
                {report.rewriteCandidateCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Survived 24h
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-sky-300">
                {report.survived24hCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Survived 72h
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-sky-200">
                {report.survived72hCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Low survival
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-orange-300">
                {report.lowSurvivalCutCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                High dwell
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-yellow-300">
                {report.highDwellLowActionCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Audio replay
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-indigo-300">
                {report.audioReplayCallbackCount}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-1">
              <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
                Old-entry revisit
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold tabular-nums text-indigo-200">
                {report.oldEntryRevisitPauseCount}
              </p>
            </CardContent>
          </Card>
        </div>
        <div className="flex flex-col gap-2">
          <Button type="button" variant="secondary" size="sm" onClick={() => downloadCallbackReviewJson(report)}>
            <Download className="mr-2 h-4 w-4" />
            Export JSON
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => downloadCallbackSurvivalJson(report)}
          >
            <Download className="mr-2 h-4 w-4" />
            Survival JSON
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => downloadCallbackPruningJson(report)}
          >
            <Download className="mr-2 h-4 w-4" />
            callback-pruning.json
          </Button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {CALLBACK_REVIEW_FILTERS.map(({ value, label }) => (
          <Button
            key={value}
            type="button"
            size="sm"
            variant={filter === value ? "default" : "secondary"}
            className="h-auto px-2.5 py-1 text-[11px]"
            onClick={() => setFilter(value)}
          >
            {label}
          </Button>
        ))}
      </div>

      <div>
        <p className="mb-3 text-xs font-medium uppercase tracking-wider text-zinc-600">
          Top pause moments
        </p>
        {report.topPauseMoments.length === 0 ? (
          <p className="text-sm text-zinc-600">No pause events recorded yet.</p>
        ) : (
          <ul className="space-y-2 rounded-xl border border-white/5 p-3">
            {report.topPauseMoments.map((row, index) => (
              <li
                key={row.id}
                className="flex cursor-pointer items-start justify-between gap-3 text-sm"
                onClick={() => handleSelect(row.id)}
              >
                <div className="min-w-0">
                  <span className="tabular-nums text-zinc-600">{index + 1}.</span>{" "}
                  <span className="text-zinc-300">{row.text}</span>
                </div>
                <span className="shrink-0 tabular-nums text-amber-200/90">{row.pauseScore}</span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div>
        <p className="mb-3 text-xs font-medium uppercase tracking-wider text-zinc-600">
          Ranked by emotional residue · pause score in table
        </p>
        <CallbackRankedTable items={items} selectedId={selectedId} onSelect={handleSelect} />
      </div>

      {items.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center text-sm text-zinc-500">
            No callbacks match this filter yet.
          </CardContent>
        </Card>
      ) : (
        items.map((item) => (
          <CallbackReviewCard
            key={`${item.kind}-${item.id}`}
            item={item}
            onLabelsChange={() => {
              bump((value) => value + 1);
              onRefresh();
            }}
          />
        ))
      )}
    </div>
  );
}
