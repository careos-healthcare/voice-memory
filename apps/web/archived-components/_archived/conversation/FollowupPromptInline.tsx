"use client";

import { useEffect } from "react";
import { Mic } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { MotionNoteItem, MotionNoteList } from "@/archived-components/_archived/motion/MotionNote";
import { buildRecordReturnFromFollowup } from "@/lib/reflection/record-return";
import { startRecordReturnFlow } from "@/lib/reflection/start-record-return";
import { recordResurfacingDismissed } from "@/lib/resurfacing/resurfacing-fatigue";
import { observeCallbackDismissed } from "@/lib/revisit/callback-learning";
import { trackContinuationSeen } from "@/lib/conversation/continuation-loops";
import type { FollowupPrompt } from "@/types/followup-prompt";

interface FollowupPromptInlineProps {
  prompt: FollowupPrompt | null;
  onRecordAgain: (prompt: FollowupPrompt) => void;
}

export function FollowupPromptInline({ prompt, onRecordAgain }: FollowupPromptInlineProps) {
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
            size="lg"
            className="mobile-touch-target min-h-[3rem]"
            data-primary-cta="recorder"
            onClick={() => {
              startRecordReturnFlow(buildRecordReturnFromFollowup(prompt));
              onRecordAgain(prompt);
            }}
          >
            <Mic className="h-5 w-5" />
            Record again
          </Button>
          <button
            type="button"
            className="text-xs text-zinc-600 hover:text-zinc-400"
            onClick={() => {
              recordResurfacingDismissed(prompt.noteId);
              observeCallbackDismissed({ id: prompt.noteId });
            }}
          >
            Not now
          </button>
        </div>
      </MotionNoteItem>
    </MotionNoteList>
  );
}
