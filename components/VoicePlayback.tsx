"use client";

import { VoiceClipPlayer } from "@/components/VoiceClipPlayer";

interface VoicePlaybackProps {
  entryId: string;
  audioId?: string;
  durationSeconds: number;
}

/** Single-entry voice playback — prefer VoicePlaybackContinuity on entry pages. */
export function VoicePlayback({
  entryId,
  audioId,
  durationSeconds,
}: VoicePlaybackProps) {
  return (
    <VoiceClipPlayer
      entryId={entryId}
      audioId={audioId}
      durationSeconds={durationSeconds}
      label="Your voice"
    />
  );
}
