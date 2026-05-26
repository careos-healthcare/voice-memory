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
import { maybeTrackRoundupFollowupRecorded } from "@/lib/roundups/roundup-observation";
import { formatEntryDate } from "@/lib/utils";
import { markFirstReflectionCreated } from "@/lib/marketing/first-session-comprehension";
import { ONBOARDING_RECORDER } from "@/lib/onboarding/onboarding-copy";
import { observeFunnelRecorderViewed } from "@/lib/retention/first-week-funnel";
import {
  pickRecurrenceDensityPrompt,
  recordRecurrenceDensityDismissed,
  recordRecurrenceDensityEngaged,
} from "@/lib/retention/recurrence-density";
import { completeFirstSessionStep } from "@/lib/onboarding/first-session-flow";
import {
  markRecorderAbandoned,
  markRecorderCompleted,
  markRecorderStarted,
} from "@/lib/onboarding/confusion-signals";
import { markFreshEntryAfterRecording } from "@/lib/refinement/entry-quiet-state";
import {
  prepareTranscriptForSaveOnce,
  trackTranscriptCleanupEvents,
} from "@/lib/transcript/transcript-cleanup";
import { getAllEntries, saveEntry } from "@/lib/storage";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { recordReflectionDuringSilence } from "@/lib/restraint/silence-intelligence";
import {
  AUDIO_SAVE_PARTIAL_COPY,
  DRAFT_RECOVERED_COPY,
} from "@/lib/reliability/copy";
import { persistTranscriptDraft, saveRecoveryDraft } from "@/lib/reliability/draft-recovery";
import { saveAudioSafe, saveDraftAudioSafe } from "@/lib/reliability/safe-audio";
import type { RecurrenceDensityPromptOffer } from "@/types/recurrence-density";
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
  const mimeTypeRef = useRef("audio/webm");
  const recorderStartedRef = useRef(false);
  const recorderCompletedRef = useRef(false);
  const navigatingAfterSaveRef = useRef(false);
  const processingRef = useRef(false);

  const [state, setState] = useState<RecorderState>("idle");
  const [seconds, setSeconds] = useState(0);
  const [stage, setStage] = useState<ProcessingStage>("transcribing");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [entry, setEntry] = useState<JournalEntry | null>(null);
  const [densityOffer, setDensityOffer] = useState<RecurrenceDensityPromptOffer | null>(null);

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

  const saveRecordingBlob = useCallback(
    async (entryId: string, blob: Blob) => {
      const result = await saveAudioSafe(entryId, blob, mimeTypeRef.current);
      if (!result.saved) {
        setNotice(AUDIO_SAVE_PARTIAL_COPY);
        return undefined;
      }
      return entryId;
    },
    [],
  );

  const finalizeEntry = useCallback(
    (newEntry: JournalEntry, recoveredDraft = false) => {
      if (navigatingAfterSaveRef.current) return;
      navigatingAfterSaveRef.current = true;
      processingRef.current = false;

      recordReflectionDuringSilence();
      trackRetentionEvent(RETENTION_EVENTS.entryRecorded, { entryId: newEntry.id });
      if (recoveredDraft) {
        setNotice(DRAFT_RECOVERED_COPY);
      }
      setEntry(newEntry);
      setState("complete");
      recorderCompletedRef.current = true;
      markRecorderCompleted();
      completeFirstSessionStep("first_reflection");
      onComplete?.(newEntry);

      window.setTimeout(() => {
        markFreshEntryAfterRecording(newEntry.id);
        router.push(`/entry/${newEntry.id}`);
      }, 1200);
    },
    [onComplete, router],
  );

  const processRecording = useCallback(
    async (blob: Blob, durationSeconds: number) => {
      if (processingRef.current) return;
      processingRef.current = true;
      navigatingAfterSaveRef.current = false;

      setState("processing");
      setStage("transcribing");
      setError(null);
      setNotice(null);

      try {
        const formData = new FormData();
        formData.append(
          "audio",
          new File([blob], "recording.webm", {
            type: blob.type || mimeTypeRef.current,
          }),
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

        const prepared = prepareTranscriptForSaveOnce(transcribeData.transcript);
        const listeningModeActive = listeningMode;

        if (listeningModeActive) {
          setStage("saving");

          const entryId = crypto.randomUUID();
          const audioId = await saveRecordingBlob(entryId, blob);

          const newEntry: JournalEntry = {
            ...createListeningModeEntry(
              entryId,
              prepared.transcript,
              durationSeconds,
              audioId,
            ),
            rawTranscript: prepared.rawTranscript,
            transcriptCleanup: prepared.transcriptCleanup,
          };

          trackTranscriptCleanupEvents(prepared.result, entryId);
          saveEntry(newEntry);
          markFirstReflectionCreated();
          finalizeEntry(newEntry);
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
          body: JSON.stringify({
            transcript: prepared.transcript,
            priorContext,
          }),
        });

        const analyzeData = (await analyzeResponse.json()) as {
          reflection?: JournalEntry["reflection"];
          error?: string;
        };

        setStage("saving");

        if (!analyzeResponse.ok || !analyzeData.reflection) {
          const entryId = crypto.randomUUID();
          const audioId = await saveRecordingBlob(entryId, blob);

          const newEntry = persistTranscriptDraft(
            prepared.rawTranscript,
            durationSeconds,
            {
              id: entryId,
              audioId,
              reason: "analysis_failed",
            },
          );

          finalizeEntry(newEntry, true);
          return;
        }

        const entryId = crypto.randomUUID();
        const audioId = await saveRecordingBlob(entryId, blob);

        const newEntry: JournalEntry = {
          id: entryId,
          createdAt: new Date().toISOString(),
          transcript: prepared.transcript,
          rawTranscript: prepared.rawTranscript,
          transcriptCleanup: prepared.transcriptCleanup,
          reflection: analyzeData.reflection,
          durationSeconds,
          audioId,
        };

        trackTranscriptCleanupEvents(prepared.result, entryId);

        try {
          saveEntry(newEntry);
          markFirstReflectionCreated();
        } catch {
          const recovered = persistTranscriptDraft(
            prepared.rawTranscript,
            durationSeconds,
            {
              id: entryId,
              audioId,
              reflection: analyzeData.reflection,
              reason: "save_failed",
            },
          );
          finalizeEntry(recovered, true);
          return;
        }

        if (reflectionPrompt || peekFollowupLoopContext()) {
          const meta = peekContinuationMeta();
          trackFollowupRecordingCompleted(newEntry.id);
          maybeTrackRoundupFollowupRecorded(meta?.noteId, newEntry.id);
          trackContinuationCompleted(
            meta?.promptId ?? "recorder-continuation",
            newEntry.id,
            meta?.noteId,
          );
          consumeContinuationMeta();
        }
        finalizeEntry(newEntry);
      } catch (processingError) {
        processingRef.current = false;
        setState("error");
        setError(
          processingError instanceof Error
            ? processingError.message
            : "Something went wrong",
        );
      }
    },
    [finalizeEntry, listeningMode, reflectionPrompt, saveRecordingBlob],
  );

  const recoverUnexpectedRecording = useCallback(
    async (blob: Blob, durationSeconds: number) => {
      if (blob.size === 0) return;

      const draftId = crypto.randomUUID();
      const audioResult = await saveDraftAudioSafe(
        draftId,
        blob,
        mimeTypeRef.current,
      );

      saveRecoveryDraft({
        id: draftId,
        transcript: "",
        durationSeconds,
        reflectionPending: true,
        audioId: audioResult.saved ? `draft-${draftId}` : undefined,
        reason: "unexpected_stop",
      });

      setState("error");
      setNotice(DRAFT_RECOVERED_COPY);
      setError(
        "Recording stopped before it could finish. Your audio was preserved when possible.",
      );
    },
    [],
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
    setNotice(null);
    setEntry(null);
    if (densityOffer) {
      recordRecurrenceDensityEngaged();
      setDensityOffer(null);
    }
    chunksRef.current = [];

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : "audio/webm";
      mimeTypeRef.current = mimeType;

      const recorder = new MediaRecorder(stream, { mimeType });
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };

      recorder.onerror = () => {
        clearTimer();
        stopTracks();
        const blob = new Blob(chunksRef.current, { type: mimeType });
        const durationSeconds = Math.max(
          1,
          Math.round((Date.now() - startTimeRef.current) / 1000),
        );
        void recoverUnexpectedRecording(blob, durationSeconds);
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
      recorderStartedRef.current = true;
      markRecorderStarted();
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
  }, [
    clearTimer,
    densityOffer,
    processRecording,
    recoverUnexpectedRecording,
    stopRecording,
    stopTracks,
  ]);

  useEffect(() => {
    if (preRecordLine || reflectionPrompt) return;
    const id = requestAnimationFrame(() => {
      setDensityOffer(pickRecurrenceDensityPrompt());
    });
    return () => cancelAnimationFrame(id);
  }, [preRecordLine, reflectionPrompt]);

  useEffect(() => {
    if (autoStart) {
      void startRecording();
    }
  }, [autoStart, startRecording]);

  useEffect(() => {
    observeFunnelRecorderViewed();
  }, []);

  useEffect(() => {
    return () => {
      clearTimer();
      stopTracks();
      if (recorderStartedRef.current && !recorderCompletedRef.current) {
        markRecorderAbandoned();
      }
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
                {preRecordLine || densityOffer ? (
                  <div className="max-w-sm text-center">
                    <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
                      {preRecordLine ?? densityOffer?.text}
                    </p>
                    {densityOffer && !preRecordLine ? (
                      <button
                        type="button"
                        onClick={() => {
                          recordRecurrenceDensityDismissed();
                          setDensityOffer(null);
                        }}
                        className="mt-2 text-xs text-zinc-600 hover:text-zinc-400"
                      >
                        Not now
                      </button>
                    ) : null}
                  </div>
                ) : null}
              </>
            )}
            <p className="text-sm text-zinc-500">{ONBOARDING_RECORDER.idle}</p>
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
            {notice ? (
              <p className="mt-2 text-sm leading-relaxed text-amber-200/80">
                {notice}
              </p>
            ) : null}
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
            {notice ? (
              <p className="text-center text-sm leading-relaxed text-amber-200/80">
                {notice}
              </p>
            ) : null}
            <div className="flex justify-center">
              <Button onClick={() => void startRecording()}>Try again</Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
