"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Mic, Square } from "lucide-react";
import { useRouter } from "next/navigation";

import {
  ErrorBanner,
  ProcessingStatus,
} from "@/components/InsightCard";
import { Button } from "@/components/ui/button";
import { saveAudio } from "@/lib/audio-storage";
import { formatEntryDate } from "@/lib/utils";
import { getAllEntries, saveEntry } from "@/lib/storage";
import type { JournalEntry, ProcessingStage } from "@/types/journal";

const MAX_SECONDS = 60;

interface RecorderProps {
  autoStart?: boolean;
  onComplete?: (entry: JournalEntry) => void;
  preRecordLine?: string | null;
}

type RecorderState =
  | "idle"
  | "recording"
  | "processing"
  | "complete"
  | "error";

export function Recorder({ autoStart = false, onComplete, preRecordLine }: RecorderProps) {
  const router = useRouter();
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);

  const [state, setState] = useState<RecorderState>("idle");
  const [seconds, setSeconds] = useState(0);
  const [stage, setStage] = useState<ProcessingStage>("transcribing");
  const [error, setError] = useState<string | null>(null);
  const [entry, setEntry] = useState<JournalEntry | null>(null);

  const clearTimer = useCallback(() => {
    if (timerRef.current) {
      window.clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const stopTracks = useCallback(() => {
    mediaRecorderRef.current?.stream
      .getTracks()
      .forEach((track) => track.stop());
  }, []);

  const processRecording = useCallback(
    async (blob: Blob, durationSeconds: number) => {
      setState("processing");
      setStage("transcribing");
      setError(null);

      try {
        const formData = new FormData();
        formData.append(
          "audio",
          new File([blob], "recording.webm", { type: blob.type || "audio/webm" }),
        );

        const transcribeResponse = await fetch("/api/transcribe", {
          method: "POST",
          body: formData,
        });

        const transcribeData = (await transcribeResponse.json()) as {
          transcript?: string;
          error?: string;
        };

        if (!transcribeResponse.ok || !transcribeData.transcript) {
          throw new Error(
            transcribeData.error ?? "Could not transcribe your recording",
          );
        }

        setStage("analyzing");

        const priorContext = getAllEntries()
          .slice(0, 5)
          .map((e) => ({
            date: formatEntryDate(e.createdAt),
            excerpt: e.transcript.slice(0, 300),
            themes: e.reflection.recurringThemes,
          }));

        const analyzeResponse = await fetch("/api/analyze", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ transcript: transcribeData.transcript, priorContext }),
        });

        const analyzeData = (await analyzeResponse.json()) as {
          reflection?: JournalEntry["reflection"];
          error?: string;
        };

        if (!analyzeResponse.ok || !analyzeData.reflection) {
          throw new Error(analyzeData.error ?? "Could not analyze your entry");
        }

        setStage("saving");

        const entryId = crypto.randomUUID();

        try {
          await saveAudio(entryId, blob, blob.type || "audio/webm");
        } catch {
          // Transcript + reflection still saved if audio storage fails (quota, etc.)
        }

        const newEntry: JournalEntry = {
          id: entryId,
          createdAt: new Date().toISOString(),
          transcript: transcribeData.transcript,
          reflection: analyzeData.reflection,
          durationSeconds,
          audioId: entryId,
        };

        saveEntry(newEntry);
        setEntry(newEntry);
        setState("complete");
        onComplete?.(newEntry);

        window.setTimeout(() => {
          router.push(`/entry/${newEntry.id}`);
        }, 1200);
      } catch (processingError) {
        setState("error");
        setError(
          processingError instanceof Error
            ? processingError.message
            : "Something went wrong",
        );
      }
    },
    [onComplete, router],
  );

  const stopRecording = useCallback(() => {
    clearTimer();
    const recorder = mediaRecorderRef.current;

    if (recorder && recorder.state !== "inactive") {
      recorder.stop();
    }
  }, [clearTimer]);

  const startRecording = useCallback(async () => {
    setError(null);
    setEntry(null);
    chunksRef.current = [];

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : "audio/webm";

      const recorder = new MediaRecorder(stream, { mimeType });
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        stopTracks();
        const blob = new Blob(chunksRef.current, { type: mimeType });
        const durationSeconds = Math.max(
          1,
          Math.round((Date.now() - startTimeRef.current) / 1000),
        );
        void processRecording(blob, durationSeconds);
      };

      startTimeRef.current = Date.now();
      recorder.start(250);
      setSeconds(0);
      setState("recording");

      timerRef.current = window.setInterval(() => {
        setSeconds((current) => {
          if (current + 1 >= MAX_SECONDS) {
            stopRecording();
            return MAX_SECONDS;
          }
          return current + 1;
        });
      }, 1000);
    } catch {
      setState("error");
      setError(
        "Microphone access is required. Please allow mic permissions and try again.",
      );
    }
  }, [processRecording, stopRecording, stopTracks]);

  useEffect(() => {
    if (autoStart) {
      void startRecording();
    }
  }, [autoStart, startRecording]);

  useEffect(() => {
    return () => {
      clearTimer();
      stopTracks();
    };
  }, [clearTimer, stopTracks]);

  const formatTime = (value: number) => {
    const mins = Math.floor(value / 60)
      .toString()
      .padStart(2, "0");
    const secs = (value % 60).toString().padStart(2, "0");
    return `${mins}:${secs}`;
  };

  return (
    <div className="w-full max-w-xl">
      <AnimatePresence mode="wait">
        {state === "idle" && (
          <motion.div
            key="idle"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="flex flex-col items-center gap-4"
          >
            <Button size="lg" onClick={() => void startRecording()}>
              <Mic className="h-5 w-5" />
              Start reflection
            </Button>
            {preRecordLine ? (
              <p className="max-w-sm text-center text-sm leading-relaxed text-zinc-500">
                {preRecordLine}
              </p>
            ) : null}
            <p className="text-sm text-zinc-500">
              Up to {MAX_SECONDS} seconds · local-first on your device
            </p>
          </motion.div>
        )}

        {state === "recording" && (
          <motion.div
            key="recording"
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
            className="flex flex-col items-center gap-6 rounded-3xl border border-red-500/20 bg-red-500/5 px-6 py-10"
          >
            <div className="relative flex h-24 w-24 items-center justify-center">
              <motion.span
                animate={{ scale: [1, 1.15, 1], opacity: [0.5, 0.2, 0.5] }}
                transition={{ duration: 1.6, repeat: Infinity }}
                className="absolute inset-0 rounded-full bg-red-500/20"
              />
              <div className="relative flex h-16 w-16 items-center justify-center rounded-full bg-red-500 shadow-lg shadow-red-500/30">
                <Mic className="h-7 w-7 text-white" />
              </div>
            </div>

            <div className="text-center">
              <p className="text-3xl font-semibold tabular-nums text-white">
                {formatTime(seconds)}
              </p>
              <p className="mt-1 text-sm text-zinc-400">
                Speak freely — we&apos;ll reflect when you stop
              </p>
            </div>

            <Button variant="destructive" size="lg" onClick={stopRecording}>
              <Square className="h-4 w-4 fill-current" />
              Stop & Reflect
            </Button>
          </motion.div>
        )}

        {state === "processing" && (
          <motion.div
            key="processing"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <ProcessingStatus stage={stage} />
          </motion.div>
        )}

        {state === "complete" && entry && (
          <motion.div
            key="complete"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center"
          >
            <p className="text-sm text-zinc-400">Saved.</p>
            <p className="mt-2 text-center text-sm text-zinc-500">
              Opening your entry…
            </p>
          </motion.div>
        )}

        {state === "error" && (
          <motion.div
            key="error"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="space-y-4"
          >
            {error ? <ErrorBanner message={error} /> : null}
            <div className="flex justify-center">
              <Button onClick={() => void startRecording()}>Try again</Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
