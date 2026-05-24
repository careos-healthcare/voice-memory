"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  clearTesterFeedback,
  downloadTesterFeedbackJson,
  readTesterFeedback,
  saveTesterFeedback,
  TESTER_FEEDBACK_LABELS,
} from "@/lib/validation/tester-feedback";
import { formatEntryDate } from "@/lib/utils";
import type { TesterFeedbackKind } from "@/types/validation-phase";

const KINDS: TesterFeedbackKind[] = [
  "felt_wrong",
  "really_landed",
  "revisited_because",
  "forgot_i_sounded",
];

export function TesterFeedbackPanel() {
  const [activeKind, setActiveKind] = useState<TesterFeedbackKind>("really_landed");
  const [text, setText] = useState("");
  const [entryId, setEntryId] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [records, setRecords] = useState(() => readTesterFeedback());

  const refresh = () => setRecords(readTesterFeedback());

  const handleSave = () => {
    try {
      saveTesterFeedback({
        kind: activeKind,
        text,
        entryId: entryId.trim() || undefined,
      });
      setText("");
      setEntryId("");
      setMessage("Saved locally.");
      refresh();
      window.setTimeout(() => setMessage(null), 3000);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save.");
    }
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Capture feedback</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {KINDS.map((kind) => (
              <Button
                key={kind}
                type="button"
                size="sm"
                variant={activeKind === kind ? "default" : "secondary"}
                className="h-auto px-2 py-1 text-[11px]"
                onClick={() => setActiveKind(kind)}
              >
                {TESTER_FEEDBACK_LABELS[kind].prompt}
              </Button>
            ))}
          </div>
          <label className="block space-y-1 text-sm text-zinc-400">
            {TESTER_FEEDBACK_LABELS[activeKind].prompt}
            <textarea
              value={text}
              onChange={(event) => setText(event.target.value)}
              rows={3}
              placeholder={TESTER_FEEDBACK_LABELS[activeKind].placeholder}
              className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
            />
          </label>
          <label className="block space-y-1 text-sm text-zinc-400">
            Entry id (optional)
            <input
              value={entryId}
              onChange={(event) => setEntryId(event.target.value)}
              className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
            />
          </label>
          <div className="flex flex-wrap gap-2">
            <Button type="button" size="sm" onClick={handleSave}>
              Save locally
            </Button>
            <Button type="button" size="sm" variant="secondary" onClick={() => downloadTesterFeedbackJson()}>
              Export JSON
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={records.length === 0}
              onClick={() => {
                clearTesterFeedback();
                refresh();
                setMessage("Feedback cleared.");
              }}
            >
              Clear all
            </Button>
          </div>
          {message ? <p className="text-sm text-zinc-500">{message}</p> : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">
            Saved notes ({records.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          {records.length === 0 ? (
            <p className="text-sm text-zinc-500">No feedback captured yet.</p>
          ) : (
            <ul className="space-y-3">
              {records.map((record) => (
                <li
                  key={record.id}
                  className="rounded-xl bg-white/[0.03] px-3 py-3 text-sm text-zinc-400"
                >
                  <p className="text-xs text-violet-300/80">
                    {TESTER_FEEDBACK_LABELS[record.kind].prompt}
                  </p>
                  <p className="mt-1 text-zinc-200">{record.text}</p>
                  <p className="mt-2 text-xs text-zinc-600">
                    {formatEntryDate(record.createdAt)}
                    {record.entryId ? ` · ${record.entryId}` : ""}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
