"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { MicOff, Pause, Play } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { getAudio } from "@/lib/audio-storage";

interface VoicePlaybackProps {
  entryId: string;
  audioId?: string;
  durationSeconds: number;
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

export function VoicePlayback({
  entryId,
  audioId,
  durationSeconds,
}: VoicePlaybackProps) {
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
      if (!audioId) {
        setStatus("missing");
        return;
      }

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

  const togglePlay = () => {
    const audio = audioRef.current;
    if (!audio) return;

    if (playing) {
      audio.pause();
    } else {
      void audio.play();
    }
  };

  const displayDuration =
    status === "ready" && currentTime > 0
      ? formatDuration(currentTime)
      : formatDuration(durationSeconds);

  if (status === "missing") {
    return (
      <Card className="border-dashed border-white/10 bg-white/[0.02]">
        <CardContent className="flex items-start gap-3 p-4">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-zinc-800">
            <MicOff className="h-4 w-4 text-zinc-500" />
          </div>
          <div>
            <p className="text-sm font-medium text-zinc-300">Recording not saved</p>
            <p className="mt-1 text-xs leading-relaxed text-zinc-500">
              This entry was created before voice playback was available, or audio
              could not be stored on this device. Your transcript and reflection are
              still here.
            </p>
            <p className="mt-2 text-xs text-zinc-600">
              Original length · {formatDuration(durationSeconds)}
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (status === "loading") {
    return (
      <Card className="border-white/10 bg-white/[0.02]">
        <CardContent className="p-4">
          <p className="text-sm text-zinc-500">Loading voice recording…</p>
        </CardContent>
      </Card>
    );
  }

  if (status === "error") {
    return (
      <Card className="border-red-500/20 bg-red-500/5">
        <CardContent className="p-4">
          <p className="text-sm text-red-200">
            Could not load audio for this entry.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="border-violet-400/20 bg-violet-500/5">
      <CardContent className="flex items-center gap-4 p-4">
        <Button
          type="button"
          size="icon"
          variant="secondary"
          className="h-12 w-12 shrink-0 rounded-full"
          onClick={togglePlay}
          aria-label={playing ? "Pause recording" : "Play recording"}
        >
          {playing ? (
            <Pause className="h-5 w-5 fill-current" />
          ) : (
            <Play className="h-5 w-5 fill-current" />
          )}
        </Button>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium text-white">Your voice</p>
          <p className="mt-0.5 text-xs text-zinc-400">
            {playing ? "Playing" : "Tap to listen"} · {displayDuration}
            {!playing ? ` / ${formatDuration(durationSeconds)}` : null}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
