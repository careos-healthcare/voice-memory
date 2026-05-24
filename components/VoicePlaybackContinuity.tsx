"use client";

import { useState } from "react";

import { VoiceClipPlayer } from "@/components/VoiceClipPlayer";
import {
  VOICE_PLAYBACK_LABELS,
  type VoicePlaybackPair,
} from "@/lib/conversation/voice-playback-continuity";

interface VoicePlaybackContinuityProps {
  pair: VoicePlaybackPair;
  onAudioPlayed?: (clip: "then" | "now") => void;
}

export function VoicePlaybackContinuity({ pair, onAudioPlayed }: VoicePlaybackContinuityProps) {
  const [activeClip, setActiveClip] = useState<"then" | "now" | null>(null);
  const labels = VOICE_PLAYBACK_LABELS[pair.kind];

  if (!pair.thenEntry) {
    return (
      <VoiceClipPlayer
        entryId={pair.nowEntry.id}
        audioId={pair.nowEntry.audioId}
        durationSeconds={pair.nowEntry.durationSeconds}
        label={labels.now}
      />
    );
  }

  return (
    <div className="grid gap-10 sm:grid-cols-2 sm:gap-8">
      <VoiceClipPlayer
        entryId={pair.thenEntry.id}
        audioId={pair.thenEntry.audioId}
        durationSeconds={pair.thenEntry.durationSeconds}
        label={labels.then ?? "Listen to an earlier moment"}
        pausedExternally={activeClip === "now"}
        onPlayStart={() => {
          setActiveClip("then");
          onAudioPlayed?.("then");
        }}
      />
      <VoiceClipPlayer
        entryId={pair.nowEntry.id}
        audioId={pair.nowEntry.audioId}
        durationSeconds={pair.nowEntry.durationSeconds}
        label={labels.now}
        pausedExternally={activeClip === "then"}
        onPlayStart={() => {
          setActiveClip("now");
          onAudioPlayed?.("now");
        }}
      />
    </div>
  );
}
