"use client";

import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  OPEN_LOOP_ENTRY_TITLE,
  OPEN_LOOP_INPUT_PLACEHOLDER,
  OPEN_LOOP_NOT_NOW,
  OPEN_LOOP_PROMPT_ALTERNATE,
  OPEN_LOOP_PROMPT_PRIMARY,
  OPEN_LOOP_SAVE_CTA,
} from "@/lib/open-loops/open-loop-copy";
import { detectUnresolvedThread } from "@/lib/open-loops/unresolved-signals";
import {
  trackOpenLoopPromptDismissed,
  trackOpenLoopPromptShown,
} from "@/lib/open-loops/open-loop-observation";
import {
  createOpenLoop,
  dismissOpenLoopPrompt,
  shouldShowOpenLoopPrompt,
} from "@/lib/open-loops/open-loop-storage";
import type { JournalEntry } from "@/types/journal";

interface OpenLoopNextStepPromptProps {
  entry: JournalEntry;
  isRevisit?: boolean;
}

function promptLineForEntry(entryId: string): string {
  let hash = 0;
  for (let i = 0; i < entryId.length; i += 1) {
    hash = (hash + entryId.charCodeAt(i)) % 2;
  }
  return hash === 0 ? OPEN_LOOP_PROMPT_PRIMARY : OPEN_LOOP_PROMPT_ALTERNATE;
}

export function OpenLoopNextStepPrompt({
  entry,
  isRevisit = false,
}: OpenLoopNextStepPromptProps) {
  const [dismissed, setDismissed] = useState(false);
  const [saved, setSaved] = useState(false);
  const [nextStep, setNextStep] = useState("");
  const [saving, setSaving] = useState(false);

  const signal = useMemo(
    () => (entry.transcript ? detectUnresolvedThread(entry.transcript) : null),
    [entry.transcript],
  );

  const promptLine = useMemo(() => promptLineForEntry(entry.id), [entry.id]);

  const visible = useMemo(() => {
    if (dismissed || saved) return false;
    if (!entry.transcript?.trim()) return false;
    return shouldShowOpenLoopPrompt(entry.id, entry.transcript, { isRevisit });
  }, [dismissed, saved, entry.id, entry.transcript, isRevisit]);

  useEffect(() => {
    if (visible) trackOpenLoopPromptShown(entry.id);
  }, [visible, entry.id]);

  if (!visible || !signal) return null;

  const handleSave = () => {
    const trimmed = nextStep.trim();
    if (!trimmed || saving) return;
    setSaving(true);
    createOpenLoop({
      sourceEntryId: entry.id,
      title: signal.title,
      userNextStep: trimmed,
      anchorPhrases: signal.anchorPhrases,
      concernLabel: signal.concernLabel,
    });
    setSaved(true);
    setSaving(false);
  };

  const handleNotNow = () => {
    dismissOpenLoopPrompt(entry.id);
    trackOpenLoopPromptDismissed(entry.id);
    setDismissed(true);
  };

  return (
    <section className="space-y-4 rounded-2xl border border-white/[0.06] bg-white/[0.02] px-4 py-5 sm:px-5">
      <p className="text-sm text-zinc-400">{OPEN_LOOP_ENTRY_TITLE}</p>
      <p className="text-sm leading-relaxed text-zinc-500">{promptLine}</p>
      <textarea
        value={nextStep}
        onChange={(event) => setNextStep(event.target.value)}
        placeholder={OPEN_LOOP_INPUT_PLACEHOLDER}
        rows={3}
        className="w-full resize-none rounded-xl border border-white/[0.08] bg-zinc-950/60 px-3 py-2.5 text-sm leading-relaxed text-zinc-300 placeholder:text-zinc-600 focus:border-white/[0.14] focus:outline-none"
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={!nextStep.trim() || saving}
          onClick={handleSave}
        >
          {saving ? "Saving…" : OPEN_LOOP_SAVE_CTA}
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="text-zinc-500 hover:text-zinc-300"
          onClick={handleNotNow}
        >
          {OPEN_LOOP_NOT_NOW}
        </Button>
      </div>
    </section>
  );
}
