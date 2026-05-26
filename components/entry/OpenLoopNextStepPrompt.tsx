"use client";

import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import { resolveOpenLoopActivation } from "@/lib/open-loops/open-loop-activation";
import {
  OPEN_LOOP_ANCHOR_LABEL,
  OPEN_LOOP_ENTRY_LEAD,
  OPEN_LOOP_ENTRY_TITLE,
  OPEN_LOOP_INPUT_PLACEHOLDER,
  OPEN_LOOP_NOT_NOW,
  OPEN_LOOP_PROMPT_ALTERNATE,
  OPEN_LOOP_PROMPT_PRIMARY,
  OPEN_LOOP_SAVE_CTA,
  OPEN_LOOP_SAVED_ACK,
} from "@/lib/open-loops/open-loop-copy";
import {
  trackOpenLoopPromptDismissed,
  trackOpenLoopPromptShown,
} from "@/lib/open-loops/open-loop-observation";
import { createOpenLoop, dismissOpenLoopPrompt } from "@/lib/open-loops/open-loop-storage";
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

  const activation = useMemo(
    () => resolveOpenLoopActivation(entry, { isRevisit }),
    [entry, isRevisit],
  );

  const promptLine = useMemo(() => promptLineForEntry(entry.id), [entry.id]);
  const anchorPhrase = activation.signal?.anchorPhrases[0];

  const visible = activation.showPrompt && !dismissed && !saved;

  useEffect(() => {
    if (visible) trackOpenLoopPromptShown(entry.id);
  }, [visible, entry.id]);

  if (!visible || !activation.signal) return null;

  const handleSave = () => {
    const trimmed = nextStep.trim();
    if (!trimmed || saving) return;
    setSaving(true);
    createOpenLoop({
      sourceEntryId: entry.id,
      title: activation.signal!.title,
      userNextStep: trimmed,
      anchorPhrases: activation.signal!.anchorPhrases,
      concernLabel: activation.signal!.concernLabel,
    });
    setSaved(true);
    setSaving(false);
  };

  const handleNotNow = () => {
    dismissOpenLoopPrompt(entry.id);
    trackOpenLoopPromptDismissed(entry.id);
    setDismissed(true);
  };

  const sectionClass = activation.prominent
    ? "space-y-4 rounded-2xl border border-violet-500/20 bg-violet-950/10 px-5 py-6 sm:px-6"
    : "space-y-4 rounded-2xl border border-white/[0.1] bg-white/[0.03] px-4 py-5 sm:px-5";

  return (
    <section className={sectionClass}>
      <div className="space-y-2">
        <p className="text-base font-normal text-zinc-300">{OPEN_LOOP_ENTRY_TITLE}</p>
        <p className="text-sm leading-relaxed text-zinc-500">{OPEN_LOOP_ENTRY_LEAD}</p>
      </div>

      {anchorPhrase ? (
        <blockquote className="border-l-2 border-white/[0.12] pl-4">
          <p className="text-xs uppercase tracking-wide text-zinc-600">
            {OPEN_LOOP_ANCHOR_LABEL}
          </p>
          <p className="mt-1.5 text-sm leading-relaxed text-zinc-400">
            &ldquo;{anchorPhrase}&rdquo;
          </p>
        </blockquote>
      ) : null}

      <p className="text-sm leading-relaxed text-zinc-500">{promptLine}</p>
      <textarea
        value={nextStep}
        onChange={(event) => setNextStep(event.target.value)}
        placeholder={OPEN_LOOP_INPUT_PLACEHOLDER}
        rows={activation.prominent ? 4 : 3}
        className="w-full resize-none rounded-xl border border-white/[0.12] bg-zinc-950/70 px-3 py-3 text-sm leading-relaxed text-zinc-200 placeholder:text-zinc-600 focus:border-violet-500/30 focus:outline-none"
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="secondary"
          size={activation.prominent ? "default" : "sm"}
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
      {saved ? (
        <p className="text-xs text-zinc-500" aria-live="polite">
          {OPEN_LOOP_SAVED_ACK}
        </p>
      ) : null}
    </section>
  );
}
