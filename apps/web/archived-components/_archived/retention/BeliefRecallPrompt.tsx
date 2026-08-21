"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  BELIEF_RECALL_DISMISS,
  BELIEF_RECALL_LEVEL_LABELS,
  BELIEF_RECALL_NOTE_QUESTION,
  BELIEF_RECALL_QUESTION,
} from "@/lib/retention/belief-recall-copy";
import {
  canShowBeliefRecallPrompt,
  dismissBeliefRecallNotePrompt,
  dismissBeliefRecallPrompt,
  saveBeliefRecallLevel,
  saveBeliefRecallNote,
  shouldShowBeliefRecallNotePrompt,
} from "@/lib/retention/belief-recall";
import { BELIEF_RECALL_LEVEL_IDS, type BeliefRecallLevelId } from "@/types/belief-recall";

type Phase = "level" | "note" | null;

export function BeliefRecallPrompt({ className = "" }: { className?: string }) {
  const [phase, setPhase] = useState<Phase>(null);
  const [noteContext, setNoteContext] = useState<{ attributionId: string } | null>(null);
  const [noteText, setNoteText] = useState("");

  const refresh = useCallback(() => {
    const pending = shouldShowBeliefRecallNotePrompt();
    if (pending) {
      setNoteContext(pending);
      setPhase("note");
      return;
    }
    if (canShowBeliefRecallPrompt()) {
      setPhase("level");
      return;
    }
    setPhase(null);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!phase) return null;

  if (phase === "note" && noteContext) {
    return (
      <Card
        className={`border-amber-500/25 bg-amber-950/15 ${className}`}
        data-testid="belief-recall-note-prompt"
      >
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-amber-100/90">
            {BELIEF_RECALL_NOTE_QUESTION}
          </CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          <textarea
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            rows={3}
            className="w-full rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-sm text-zinc-200"
            placeholder="Optional — a phrase or moment that stayed with you"
          />
          <Button
            type="button"
            size="sm"
            onClick={() => {
              saveBeliefRecallNote(noteText, noteContext.attributionId);
              setPhase(null);
              setNoteContext(null);
              setNoteText("");
            }}
          >
            Save
          </Button>
          <button
            type="button"
            onClick={() => {
              dismissBeliefRecallNotePrompt();
              setPhase(null);
              setNoteContext(null);
            }}
            className="text-xs text-zinc-600 hover:text-zinc-400"
          >
            {BELIEF_RECALL_DISMISS}
          </button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card
      className={`border-amber-500/30 bg-amber-950/10 ${className}`}
      data-testid="belief-recall-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-amber-100/90">
          {BELIEF_RECALL_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {BELIEF_RECALL_LEVEL_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start py-2 text-left"
            onClick={() => {
              saveBeliefRecallLevel(id as BeliefRecallLevelId);
              const pending = shouldShowBeliefRecallNotePrompt();
              if (pending && (id === "yes_clearly" || id === "vaguely")) {
                setNoteContext(pending);
                setPhase("note");
              } else {
                setPhase(null);
              }
            }}
          >
            {BELIEF_RECALL_LEVEL_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={() => {
            dismissBeliefRecallPrompt();
            setPhase(null);
          }}
          className="text-xs text-zinc-600 hover:text-zinc-400"
        >
          {BELIEF_RECALL_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
