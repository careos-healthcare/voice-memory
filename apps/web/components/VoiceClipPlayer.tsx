"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { MicOff, Pause, Play } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getAudio } from "@/lib/audio-storage";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";

interface VoiceClipPlayerProps {
  entryId: string;
  audioId?: string;
  durationSeconds: number;
  label: string;
  pausedExternally?: boolean;
  onPlayStart?: () => void;
}

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
    .toString()
    .padStart(2, "0");
  const secs = Math.floor(seconds % 60)
    .toString()
    .padStart(2, "0");
  return `${mins}:${secs}`;
}

export function VoiceClipPlayer({
  entryId,
  audioId,
  durationSeconds,
  label,
  pausedExternally = false,
  onPlayStart,
}: VoiceClipPlayerProps) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const objectUrlRef = useRef<string | null>(null);

  const [status, setStatus] = useState<"loading" | "ready" | "missing" | "error">(
    "loading",
  );
  const [playing, setPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);

  const cleanup = useCallback(() => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current = null;
    }
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }
    setPlaying(false);
    setCurrentTime(0);
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const stored = await getAudio(entryId);
        if (cancelled) return;

        if (!stored) {
          setStatus("missing");
          return;
        }

        const url = URL.createObjectURL(stored.blob);
        objectUrlRef.current = url;

        const audio = new Audio(url);
        audioRef.current = audio;

        audio.addEventListener("timeupdate", () => {
          setCurrentTime(audio.currentTime);
        });
        audio.addEventListener("ended", () => {
          setPlaying(false);
          setCurrentTime(0);
        });
        audio.addEventListener("pause", () => setPlaying(false));
        audio.addEventListener("play", () => setPlaying(true));

        setStatus("ready");
      } catch {
        if (!cancelled) setStatus("error");
      }
    }

    void load();

    return () => {
      cancelled = true;
      cleanup();
    };
  }, [audioId, cleanup, entryId]);

  useEffect(() => {
    if (pausedExternally && audioRef.current && playing) {
      audioRef.current.pause();
    }
  }, [pausedExternally, playing]);

  const togglePlay = () => {
    const audio = audioRef.current;
    if (!audio) return;

    if (playing) {
      audio.pause();
      return;
    }

    onPlayStart?.();
    trackRetentionEvent(RETENTION_EVENTS.audioPlayed, { entryId });
    void audio.play();
  };

  const displayDuration =
    status === "ready" && currentTime > 0
      ? formatDuration(currentTime)
      : formatDuration(durationSeconds);

  return (
    <div className="space-y-3 px-1">
      <p className="text-sm font-normal leading-relaxed text-zinc-500">{label}</p>

      {status === "loading" ? (
        <p className="text-xs text-zinc-600">Loading recording…</p>
      ) : null}

      {status === "missing" ? (
        <div className="flex items-start gap-2 text-xs leading-relaxed text-zinc-600">
          <MicOff className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          <p>Recording not saved for this moment. Your words are still here.</p>
        </div>
      ) : null}

      {status === "error" ? (
        <p className="text-xs text-zinc-600">Could not load this recording.</p>
      ) : null}

      {status === "ready" ? (
        <div className="flex items-center gap-3">
          <Button
            type="button"
            size="icon"
            variant="ghost"
            className="h-10 w-10 shrink-0 rounded-full bg-white/[0.04] hover:bg-white/[0.07]"
            onClick={togglePlay}
            aria-label={playing ? "Pause recording" : "Play recording"}
          >
            {playing ? (
              <Pause className="h-4 w-4 fill-current text-zinc-300" />
            ) : (
              <Play className="h-4 w-4 fill-current text-zinc-300" />
            )}
          </Button>
          <p className="text-xs text-zinc-600">
            {playing ? "Playing" : "Tap to listen"} · {displayDuration}
            {!playing ? ` / ${formatDuration(durationSeconds)}` : null}
          </p>
        </div>
      ) : null}
    </div>
  );
}
