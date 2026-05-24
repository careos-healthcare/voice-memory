"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Mic, Square } from "lucide-react";
import { useRouter } from "next/navigation";

import {
  ErrorBanner,
  ProcessingStatus,
} from "@/components/InsightCardStatus";
import { Button } from "@/components/ui/button";
import { MOTION } from "@/lib/motion/tokens";
import { presenceFade } from "@/lib/motion/variants";
import { useListeningMode } from "@/lib/hooks/useListeningMode";
import { saveAudio } from "@/lib/audio-storage";
import { LISTENING_SAVED_COPY } from "@/lib/listening-mode";
import { createListeningModeEntry } from "@/lib/pending-reflection";
import { ContinuationRecorderPrompt } from "@/components/conversation/ContinuationRecorderPrompt";
import {
  consumeContinuationMeta,
  peekContinuationMeta,
  trackContinuationCompleted,
} from "@/lib/conversation/continuation-loops";
import {
  peekFollowupLoopContext,
  trackFollowupRecordingCompleted,
} from "@/lib/retention/retention-loops";
import { formatEntryDate } from "@/lib/utils";
import { getAllEntries, saveEntry } from "@/lib/storage";
import type { JournalEntry, ProcessingStage } from "@/types/journal";

const MAX_SECONDS = 60;

interface RecorderProps {
  autoStart?: boolean;
  onComplete?: (entry: JournalEntry) => void;
  preRecordLine?: string | null;
  reflectionPrompt?: string | null;
}

type RecorderState =
  | "idle"
  | "recording"
  | "processing"
  | "complete"
  | "error";

export function Recorder({
  autoStart = false,
  onComplete,
  preRecordLine,
  reflectionPrompt,
}: RecorderProps) {
  const router = useRouter();
  const { listeningMode } = useListeningMode();
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

        const listeningModeActive = listeningMode;

        if (listeningModeActive) {
          setStage("saving");

          const entryId = crypto.randomUUID();

          try {
            await saveAudio(entryId, blob, blob.type || "audio/webm");
          } catch {
            // Transcript still saved if audio storage fails
          }

          const newEntry = createListeningModeEntry(
            entryId,
            transcribeData.transcript,
            durationSeconds,
            entryId,
          );

          saveEntry(newEntry);
          setEntry(newEntry);
          setState("complete");
          onComplete?.(newEntry);

          window.setTimeout(() => {
            router.push(`/entry/${newEntry.id}`);
          }, 1200);
          return;
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
        if (reflectionPrompt || peekFollowupLoopContext()) {
          const meta = peekContinuationMeta();
          trackFollowupRecordingCompleted(newEntry.id);
          trackContinuationCompleted(
            meta?.promptId ?? "recorder-continuation",
            newEntry.id,
            meta?.noteId,
          );
          consumeContinuationMeta();
        }
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
    [onComplete, router, listeningMode, reflectionPrompt],
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
            variants={presenceFade}
            initial="initial"
            animate="animate"
            exit="exit"
            className="flex flex-col items-center gap-5"
          >
            {reflectionPrompt ? (
              <ContinuationRecorderPrompt
                text={reflectionPrompt}
                onContinue={() => void startRecording()}
              />
            ) : (
              <>
                <Button size="lg" onClick={() => void startRecording()}>
                  <Mic className="h-5 w-5" />
                  Start reflection
                </Button>
                {preRecordLine ? (
                  <p className="max-w-sm text-center text-sm font-normal leading-[1.75] text-zinc-500/90">
                    {preRecordLine}
                  </p>
                ) : null}
              </>
            )}
            <p className="text-sm text-zinc-500">
              Up to {MAX_SECONDS} seconds · local-first on your device
            </p>
          </motion.div>
        )}

        {state === "recording" && (
          <motion.div
            key="recording"
            variants={presenceFade}
            initial="initial"
            animate="animate"
            exit="exit"
            className="flex flex-col items-center gap-7 px-6 py-10"
          >
            <div className="relative flex h-24 w-24 items-center justify-center">
              <motion.span
                animate={{ scale: [1, 1.08, 1], opacity: [0.35, 0.15, 0.35] }}
                transition={{ duration: 2.4, repeat: Infinity, ease: MOTION.ease }}
                className="absolute inset-0 rounded-full bg-red-500/15"
              />
              <div className="relative flex h-16 w-16 items-center justify-center rounded-full bg-red-500/90 shadow-lg shadow-red-500/20">
                <Mic className="h-7 w-7 text-white" />
              </div>
            </div>

            <div className="text-center">
              <p className="text-3xl font-normal tabular-nums text-zinc-100">
                {formatTime(seconds)}
              </p>
              <p className="mt-2 text-sm leading-relaxed text-zinc-500">
                {listeningMode
                  ? "Speak freely — we'll save when you stop"
                  : "Speak freely — we'll reflect when you stop"}
              </p>
            </div>

            <Button variant="destructive" size="lg" onClick={stopRecording}>
              <Square className="h-4 w-4 fill-current" />
              {listeningMode ? "Stop & Save" : "Stop & Reflect"}
            </Button>
          </motion.div>
        )}

        {state === "processing" && (
          <motion.div
            key="processing"
            variants={presenceFade}
            initial="initial"
            animate="animate"
            exit="exit"
          >
            <ProcessingStatus stage={stage} />
          </motion.div>
        )}

        {state === "complete" && entry && (
          <motion.div
            key="complete"
            variants={presenceFade}
            initial="initial"
            animate="animate"
            className="text-center"
          >
            <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
              {listeningMode ? LISTENING_SAVED_COPY : "Saved."}
            </p>
            <p className="mt-2 text-center text-sm text-zinc-500">
              Opening your entry…
            </p>
          </motion.div>
        )}

        {state === "error" && (
          <motion.div
            key="error"
            variants={presenceFade}
            initial="initial"
            animate="animate"
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
