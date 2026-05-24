"use client";

import { Button } from "@/components/ui/button";
import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import { recordFollowupContinued } from "@/lib/callback-interaction-signals";
import { markFollowupBoost } from "@/lib/refinement/emotional-timing";
import { trackFollowupRecordingStarted } from "@/lib/retention/retention-loops";
import { trackRevisitRhythmFollowupIfActive } from "@/lib/refinement/revisit-rhythm";
import type { FollowupPrompt } from "@/types/followup-prompt";

interface FollowupPromptInlineProps {
  prompt: FollowupPrompt | null;
  onContinue: (prompt: FollowupPrompt) => void;
}

export function FollowupPromptInline({ prompt, onContinue }: FollowupPromptInlineProps) {
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
              if (prompt.noteId) {
                recordFollowupContinued(prompt.noteId);
                trackFollowupRecordingStarted(prompt.noteId, prompt.id);
                markFollowupBoost();
              }
              trackRevisitRhythmFollowupIfActive(prompt.noteId ?? prompt.id, prompt.id);
              onContinue(prompt);
            }}
          >
            Continue this thought
          </Button>
        </div>
      </MotionNoteItem>
    </MotionNoteList>
  );
}
