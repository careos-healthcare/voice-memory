"use client";

import { useEffect } from "react";

import { Button } from "@/components/ui/button";
import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import { recordFollowupContinued } from "@/lib/callback-interaction-signals";
import {
  storeContinuationMeta,
  trackContinuationSeen,
  trackContinuationStarted,
} from "@/lib/conversation/continuation-loops";
import { markFollowupBoost } from "@/lib/refinement/emotional-timing";
import { trackFollowupRecordingStarted } from "@/lib/retention/retention-loops";
import { trackFollowUpAfterCallback } from "@/lib/retention/pause-moments";
import { trackRevisitRhythmFollowupIfActive } from "@/lib/refinement/revisit-rhythm";
import type { FollowupPrompt } from "@/types/followup-prompt";

interface FollowupPromptInlineProps {
  prompt: FollowupPrompt | null;
  onContinue: (prompt: FollowupPrompt) => void;
}

export function FollowupPromptInline({ prompt, onContinue }: FollowupPromptInlineProps) {
  useEffect(() => {
    if (!prompt) return;
    trackContinuationSeen(prompt.id, prompt.noteId);
  }, [prompt?.id, prompt?.noteId]);

  if (!prompt) return null;

  return (
    <MotionNoteList className="py-1">
      <MotionNoteItem tone="quiet" index={0}>
        <div className="space-y-4 px-1 py-2">
          <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">{prompt.text}</p>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-auto px-0 text-sm text-zinc-400 hover:bg-transparent hover:text-zinc-200"
            onClick={() => {
              storeContinuationMeta(prompt.id, prompt.noteId);
              trackContinuationStarted(prompt.id, prompt.noteId);
              if (prompt.noteId) {
                recordFollowupContinued(prompt.noteId);
                trackFollowupRecordingStarted(prompt.noteId, prompt.id);
                trackFollowUpAfterCallback(prompt.noteId, prompt.id);
                markFollowupBoost();
              }
              trackRevisitRhythmFollowupIfActive(prompt.noteId ?? prompt.id, prompt.id);
              onContinue(prompt);
            }}
          >
            Continue
          </Button>
        </div>
      </MotionNoteItem>
    </MotionNoteList>
  );
}
