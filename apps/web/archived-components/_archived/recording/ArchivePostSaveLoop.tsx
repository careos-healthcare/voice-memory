"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  ARCHIVE_UPDATED_LINE,
  POST_SAVE_KEEP_RECORDING_LABEL,
} from "@/lib/archive/archive-record-copy";
import type { ArchivePostSaveFollowUp } from "@/types/archive-prompt";

type ArchivePostSaveLoopProps = {
  followUp: ArchivePostSaveFollowUp;
  onKeepRecording: () => void;
  className?: string;
};

export function ArchivePostSaveLoop({
  followUp,
  onKeepRecording,
  className = "",
}: ArchivePostSaveLoopProps) {
  return (
    <div
      className={`mx-auto w-full max-w-md space-y-4 rounded-2xl border border-violet-500/25 bg-violet-950/20 px-4 py-5 text-center ${className}`}
      data-testid="archive-post-save-loop"
    >
      <p className="text-sm font-medium text-violet-100/95">{ARCHIVE_UPDATED_LINE}</p>
      <p className="text-sm leading-relaxed text-zinc-300">{followUp.text}</p>
      <Button
        type="button"
        size="lg"
        className="mobile-touch-target w-full min-h-11"
        data-testid="archive-post-save-keep-recording"
        onClick={onKeepRecording}
      >
        {POST_SAVE_KEEP_RECORDING_LABEL}
      </Button>
    </div>
  );
}
