"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  EmotionalRecognitionQaClass,
  EmotionalRecognitionQaChecklist,
  EmotionalRecognitionQaReport,
  EmotionalRecognitionQaRow,
} from "@/lib/debug/emotional-recognition-qa";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

const QA_CLASS_LABELS: Record<EmotionalRecognitionQaClass, string> = {
  earned_specific: "Earned & specific",
  vague_generic: "Vague / generic",
  creepy_overreach: "Creepy overreach",
  too_soon: "Too soon",
  too_late: "Too late",
  obvious_low_value: "Obvious / low value",
  strong_recognition: "Strong recognition",
};

const CHECKLIST_LABELS: Record<keyof EmotionalRecognitionQaChecklist, string> = {
  answersWhyNow: 'Answers "why now?"',
  referencesPriorWords: "References real prior words",
  wouldFeelRandom: "Would feel random",
  tooTherapeutic: "Too therapeutic",
  tooObvious: "Too obvious",
  specificEnoughForRecognition: "Specific enough for recognition",
};

function ChecklistItem({
  label,
  pass,
  invert = false,
}: {
  label: string;
  pass: boolean;
  invert?: boolean;
}) {
  const flagged = invert ? pass : !pass;
  return (
    <p className={`text-xs ${flagged ? "text-amber-400/90" : "text-emerald-400/80"}`}>
      {flagged ? "✗" : "✓"} {label}
    </p>
  );
}

function QaRowCard({ row }: { row: EmotionalRecognitionQaRow }) {
  return (
    <div className="border-b border-white/5 py-4 text-sm last:border-b-0">
      <div className="flex flex-wrap items-center gap-2">
        <span className="rounded-full bg-violet-500/15 px-2 py-0.5 text-xs text-violet-200">
          {QA_CLASS_LABELS[row.qaClass]}
        </span>
        <span className="text-xs text-zinc-600">{row.noteId}</span>
        {row.blocked ? (
          <span className="text-xs text-amber-500/80">blocked</span>
        ) : null}
      </div>

      <p className="mt-2 text-zinc-200">{row.callbackCopy}</p>

      {row.whyNowReason ? (
        <p className="mt-2 text-xs text-violet-300/80">Why now: {row.whyNowReason}</p>
      ) : (
        <p className="mt-2 text-xs text-zinc-600">Why now: —</p>
      )}

      <p className="mt-2 text-xs text-zinc-500">
        Internal confidence {row.confidenceScore} · {row.confidenceClassification.replace(/_/g, " ")}
      </p>

      <p className="mt-1 text-xs text-zinc-500">
        Timing: {row.timingEligible ? "eligible" : "blocked"} · {row.timingClass.replace(/_/g, " ")}
        {row.timingSuppressReasons.length > 0
          ? ` · ${row.timingSuppressReasons.join(", ").replace(/_/g, " ")}`
          : ""}
      </p>

      {row.evidenceSignals.length > 0 ? (
        <p className="mt-1 text-xs text-zinc-600">
          Evidence: {row.evidenceSignals.join(" · ").replace(/_/g, " ")}
        </p>
      ) : null}

      {row.sourceEntrySnippet ? (
        <p className="mt-2 text-xs text-zinc-500">
          <span className="text-zinc-600">Source:</span> {row.sourceEntrySnippet}
        </p>
      ) : null}
      {row.currentEntrySnippet ? (
        <p className="mt-1 text-xs text-zinc-500">
          <span className="text-zinc-600">Current:</span> {row.currentEntrySnippet}
        </p>
      ) : null}

      {row.suppressReason ? (
        <p className="mt-2 text-xs text-amber-500/80">
          Suppress: {row.suppressReason.replace(/_/g, " ")}
        </p>
      ) : null}

      {row.suggestedCopyRepair ? (
        <p className="mt-2 text-xs text-emerald-300/80">
          Suggested repair: {row.suggestedCopyRepair}
        </p>
      ) : null}

      <div className="mt-3 space-y-1 rounded-md border border-white/[0.04] bg-zinc-950/40 p-3">
        <p className="text-xs uppercase tracking-wide text-zinc-600">QA checklist</p>
        <ChecklistItem label={CHECKLIST_LABELS.answersWhyNow} pass={row.checklist.answersWhyNow} />
        <ChecklistItem
          label={CHECKLIST_LABELS.referencesPriorWords}
          pass={row.checklist.referencesPriorWords}
        />
        <ChecklistItem
          label={CHECKLIST_LABELS.wouldFeelRandom}
          pass={row.checklist.wouldFeelRandom}
          invert
        />
        <ChecklistItem
          label={CHECKLIST_LABELS.tooTherapeutic}
          pass={row.checklist.tooTherapeutic}
          invert
        />
        <ChecklistItem label={CHECKLIST_LABELS.tooObvious} pass={row.checklist.tooObvious} invert />
        <ChecklistItem
          label={CHECKLIST_LABELS.specificEnoughForRecognition}
          pass={row.checklist.specificEnoughForRecognition}
        />
      </div>
    </div>
  );
}

export function EmotionalRecognitionQaPanel({ report }: { report: EmotionalRecognitionQaReport }) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Candidates reviewed" value={String(report.totalReviewed)} />
          {(Object.keys(QA_CLASS_LABELS) as EmotionalRecognitionQaClass[]).map((qaClass) => (
            <Row
              key={qaClass}
              label={QA_CLASS_LABELS[qaClass]}
              value={String(report.byClass[qaClass])}
            />
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Checklist pass rates</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {(Object.keys(CHECKLIST_LABELS) as Array<keyof EmotionalRecognitionQaChecklist>).map(
            (key) => (
              <Row
                key={key}
                label={CHECKLIST_LABELS[key]}
                value={`${report.checklistSummary[key]} / ${report.totalReviewed}`}
              />
            ),
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent candidates</CardTitle>
        </CardHeader>
        <CardContent>
          {!report.hasData ? (
            <p className="text-sm text-zinc-500">No resurfacing candidates in local data yet.</p>
          ) : (
            report.rows.map((row) => <QaRowCard key={row.noteId} row={row} />)
          )}
        </CardContent>
      </Card>
    </div>
  );
}
