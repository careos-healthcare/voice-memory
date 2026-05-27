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
import {
  createListeningModeEntry,
  createPendingReflection,
} from "@/lib/pending-reflection";
import { RecordReturnAnchor } from "@/components/recording/RecordReturnAnchor";
import { RECORDER_PRIMARY_LABEL } from "@/lib/reflection/recorder-primary-label";
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
import { getAllEntries, getEntry, saveEntry } from "@/lib/storage";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";
import { recordReflectionDuringSilence } from "@/lib/restraint/silence-intelligence";
import {
  AUDIO_SAVE_PARTIAL_COPY,
  DRAFT_RECOVERED_COPY,
} from "@/lib/reliability/copy";
import { persistTranscriptDraft, saveRecoveryDraft } from "@/lib/reliability/draft-recovery";
import { saveAudioSafe, saveDraftAudioSafe } from "@/lib/reliability/safe-audio";
import { usePrimaryCtaClaim } from "@/components/homepage/HomepagePrimaryCtaProvider";
import {
  consumeRecordReturnContext,
  peekRecordReturnContext,
  RECORD_RETURN_SAVED_LINE,
} from "@/lib/reflection/record-return";
import {
  consumeAfterSaveContinuityLine,
  finalizeAfterSaveContinuity,
} from "@/lib/reflection/after-save-continuity";
import { isQuickReflectionEnabled } from "@/lib/reflection/quick-reflection";
import { recordResurfacingOpenedWithoutReflection } from "@/lib/resurfacing/resurfacing-fatigue";
import { observeReflectionAfterCallback } from "@/lib/revisit/callback-learning";
import { pickAfterSaveClarityLine } from "@/lib/clarity/after-save-clarity";
import {
  consumeClarityRecordContext,
  peekClarityRecordContext,
  storeClarityAfterSaveLine,
  type ClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import {
  writeEnqueueThoughtPatternExtract,
  writeLinkReflectionAfterResurface,
  writeTrackClarityAbandoned,
  writeTrackClarityFollowupSaved,
} from "@/lib/runtime/write-actions";
import {
  detectThinkingOutLoudSignals,
  qualifiesForClarityPrompt,
} from "@/lib/clarity/thinking-out-loud-signals";
import { recordReflectionAfterResurface } from "@/lib/resurfacing/resurfacing-fatigue";
import { observeReflectionAfterMode } from "@/lib/resurfacing/resurfacing-mode-observation";
import {
  peekReflexCaptureContext,
  type ReflexCaptureContext,
} from "@/lib/reflex/reflex-context";
import { markRecorderEngaged } from "@/lib/reflex/read-vs-speak";
import {
  markReflexRecordingStarted,
  markReflexRecorderMounted,
} from "@/lib/reflex/reflex-observation";
import { maybeRecordFirstReturnRerecordWithin10Min } from "@/lib/continuity/first-return-observation";
import { recordReflexSessionRecording } from "@/lib/reflex/open-without-record";
import {
  isMicrophonePermissionGranted,
  markMicrophonePermissionGranted,
} from "@/lib/capture/fast-capture";
import { MIC_PERMISSION_COPY } from "@/lib/capture/mic-permission-copy";
import {
  clearMicPermissionRequestActive,
  markMicPermissionRequestActive,
  setRecorderSurfaceActive,
} from "@/lib/mobile/install-prompt-gate";
import {
  isLikelyOffline,
  isNetworkFetchError,
  OFFLINE_TRANSCRIPTION_RETRY_HINT,
  OFFLINE_TRANSCRIPTION_SAVED_COPY,
  saveOfflineRecordingDraft,
  sanitizeRecordingErrorMessage,
} from "@/lib/reliability/offline-transcription";
import { MicPermissionPanel } from "@/components/recording/MicPermissionPanel";
import {
  clearForceDirectMicAfterCapture,
  clearHesitationWatch,
  markSpeechStartedAfterHesitation,
} from "@/lib/capture/hesitation-signals";
import {
  markRecordingStartedForVulnerability,
  markVulnerablePhraseDetected,
} from "@/lib/capture/vulnerability-timing";
import { recordInterruptionOutcome } from "@/lib/capture/interruption-timing";
import type { RecurrenceDensityPromptOffer } from "@/types/recurrence-density";
import type { RecordReturnContext as RecordReturnContextType } from "@/types/record-return";
import type { JournalEntry, ProcessingStage } from "@/types/journal";

const MAX_SECONDS = 60;

interface RecorderProps {
  autoStart?: boolean;
  onComplete?: (entry: JournalEntry) => void;
  preRecordLine?: string | null;
  /** @deprecated Use recordReturn — one-tap return flow with anchor quote. */
  reflectionPrompt?: string | null;
  recordReturn?: RecordReturnContextType | null;
  clarityRecord?: ClarityRecordContext | null;
  reflexCapture?: ReflexCaptureContext | null;
  /** Faster boot — defer extras, prioritize mic. */
  reflexFastBoot?: boolean;
  /** Zero-state capture — one line max, no density/explanation modules. */
  zeroState?: boolean;
  captureContext?: string;
  quickReflection?: boolean;
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
  recordReturn: recordReturnProp,
  clarityRecord: clarityRecordProp,
  reflexCapture: reflexCaptureProp,
  reflexFastBoot = false,
  zeroState = false,
  captureContext = "recorder",
  quickReflection = false,
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
  const lastRecordingRef = useRef<{ blob: Blob; durationSeconds: number } | null>(
    null,
  );
  const [micBlocked, setMicBlocked] = useState(false);
  const [pendingOfflineRetry, setPendingOfflineRetry] = useState(false);
  const processingRef = useRef(false);

  const [state, setState] = useState<RecorderState>("idle");
  const [seconds, setSeconds] = useState(0);
  const [stage, setStage] = useState<ProcessingStage>("transcribing");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [entry, setEntry] = useState<JournalEntry | null>(null);
  const [densityOffer, setDensityOffer] = useState<RecurrenceDensityPromptOffer | null>(null);
  const [liveTranscript, setLiveTranscript] = useState<string | null>(null);
  const [continuityLine, setContinuityLine] = useState<string | null>(null);
  const recordReturnRef = useRef<RecordReturnContextType | null>(recordReturnProp ?? null);
  const clarityRecordRef = useRef<ClarityRecordContext | null>(clarityRecordProp ?? null);
  const reflexCaptureRef = useRef<ReflexCaptureContext | null>(reflexCaptureProp ?? null);
  const quickMode =
    quickReflection || isQuickReflectionEnabled() || reflexFastBoot || zeroState;

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

  useEffect(() => {
    recordReturnRef.current = recordReturnProp ?? peekRecordReturnContext() ?? null;
    clarityRecordRef.current = clarityRecordProp ?? peekClarityRecordContext() ?? null;
    reflexCaptureRef.current = reflexCaptureProp ?? peekReflexCaptureContext() ?? null;
  }, [clarityRecordProp, recordReturnProp, reflexCaptureProp]);

  const completeClarityAfterSave = useCallback((newEntry: JournalEntry) => {
    const ctx = clarityRecordRef.current ?? consumeClarityRecordContext();
    if (!ctx) return false;
    clarityRecordRef.current = null;
    const prior = getEntry(ctx.sourceEntryId);
    const line = pickAfterSaveClarityLine(prior ?? undefined, newEntry, ctx);
    if (line) {
      storeClarityAfterSaveLine(line);
      setContinuityLine(line);
    }
    writeTrackClarityFollowupSaved(ctx.entryId, newEntry.id);
    writeEnqueueThoughtPatternExtract({
      entryId: newEntry.id,
      transcript: newEntry.transcript,
    });
    return true;
  }, []);

  const completeRecordReturnAfterSave = useCallback((newEntry: JournalEntry) => {
    const returnCtx = recordReturnRef.current ?? consumeRecordReturnContext();
    if (!returnCtx) {
      const deferred = consumeAfterSaveContinuityLine();
      if (deferred) setContinuityLine(deferred.text);
      return;
    }
    recordReturnRef.current = null;
    writeLinkReflectionAfterResurface(newEntry);
    observeReflectionAfterCallback({ id: returnCtx.noteId });
    recordReflectionAfterResurface(returnCtx.noteId);
    observeReflectionAfterMode(
      { id: returnCtx.noteId, pastEntryId: returnCtx.pastEntryId, text: returnCtx.anchorQuote },
      undefined,
      returnCtx.returnMode,
    );
    finalizeAfterSaveContinuity(newEntry, returnCtx);
    setContinuityLine(RECORD_RETURN_SAVED_LINE);
  }, []);

  const finalizeEntry = useCallback(
    (newEntry: JournalEntry, recoveredDraft = false) => {
      if (navigatingAfterSaveRef.current) return;
      navigatingAfterSaveRef.current = true;
      processingRef.current = false;

      recordReflectionDuringSilence();
      void import("@/lib/retention/session-retention").then((mod) => {
        mod.observeSessionReflectionAfterCallbackIfPending();
      });
      trackRetentionEvent(RETENTION_EVENTS.entryRecorded, { entryId: newEntry.id });
      if (recoveredDraft) {
        setNotice(DRAFT_RECOVERED_COPY);
      }
      setEntry(newEntry);
      setState("complete");
      recorderCompletedRef.current = true;
      markRecorderCompleted();
      clearForceDirectMicAfterCapture();
      completeFirstSessionStep("first_reflection");
      onComplete?.(newEntry);

      recordReflexSessionRecording();
      const delayMs =
        reflexFastBoot || quickMode || recordReturnRef.current || reflexCaptureRef.current
          ? 500
          : 1200;
      window.setTimeout(() => {
        markFreshEntryAfterRecording(newEntry.id);
        router.push(`/entry/${newEntry.id}`);
      }, delayMs);
    },
    [onComplete, quickMode, reflexFastBoot, router],
  );

  const processRecording = useCallback(
    async (blob: Blob, durationSeconds: number) => {
      if (processingRef.current) return;
      processingRef.current = true;
      navigatingAfterSaveRef.current = false;
      lastRecordingRef.current = { blob, durationSeconds };

      setState("processing");
      setStage("transcribing");
      setError(null);
      setNotice(null);
      setMicBlocked(false);
      setPendingOfflineRetry(false);

      try {
        const formData = new FormData();
        formData.append(
          "audio",
          new File([blob], "recording.webm", {
            type: blob.type || mimeTypeRef.current,
          }),
        );

        let transcribeResponse: Response;
        try {
          transcribeResponse = await fetch("/api/transcribe", {
            method: "POST",
            body: formData,
          });
        } catch (fetchError) {
          if (isNetworkFetchError(fetchError) || isLikelyOffline()) {
            await saveOfflineRecordingDraft(
              blob,
              durationSeconds,
              mimeTypeRef.current,
            );
            processingRef.current = false;
            setState("error");
            setPendingOfflineRetry(true);
            setNotice(OFFLINE_TRANSCRIPTION_SAVED_COPY);
            setError(OFFLINE_TRANSCRIPTION_RETRY_HINT);
            return;
          }
          throw fetchError;
        }

        const transcribeData = (await transcribeResponse.json()) as {
          transcript?: string;
          error?: string;
        };

        if (!transcribeResponse.ok || !transcribeData.transcript) {
          if (!transcribeResponse.ok && (isLikelyOffline() || transcribeResponse.status >= 500)) {
            await saveOfflineRecordingDraft(
              blob,
              durationSeconds,
              mimeTypeRef.current,
            );
            processingRef.current = false;
            setState("error");
            setPendingOfflineRetry(true);
            setNotice(OFFLINE_TRANSCRIPTION_SAVED_COPY);
            setError(OFFLINE_TRANSCRIPTION_RETRY_HINT);
            return;
          }
          throw new Error(
            transcribeData.error ?? "Could not transcribe your recording",
          );
        }

        const prepared = prepareTranscriptForSaveOnce(transcribeData.transcript);
        const listeningModeActive = listeningMode;

        setLiveTranscript(prepared.transcript);
        markVulnerablePhraseDetected(prepared.transcript, captureContext);

        if ((quickMode || reflexFastBoot) && !listeningModeActive) {
          setStage("saving");
          const entryId = crypto.randomUUID();
          const audioId = await saveRecordingBlob(entryId, blob);
          const newEntry: JournalEntry = {
            id: entryId,
            createdAt: new Date().toISOString(),
            transcript: prepared.transcript,
            rawTranscript: prepared.rawTranscript,
            transcriptCleanup: prepared.transcriptCleanup,
            reflection: createPendingReflection(),
            durationSeconds,
            audioId,
          };
          trackTranscriptCleanupEvents(prepared.result, entryId);
          saveEntry(newEntry);
          markFirstReflectionCreated();
          if (!completeClarityAfterSave(newEntry)) {
            completeRecordReturnAfterSave(newEntry);
          }
          const signals = detectThinkingOutLoudSignals(newEntry.transcript);
          if (qualifiesForClarityPrompt(signals)) {
            writeEnqueueThoughtPatternExtract({
              entryId: newEntry.id,
              transcript: newEntry.transcript,
            });
          }
          finalizeEntry(newEntry);
          return;
        }

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

        if (
          reflectionPrompt ||
          recordReturnRef.current ||
          peekFollowupLoopContext()
        ) {
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
        if (!completeClarityAfterSave(newEntry)) {
          completeRecordReturnAfterSave(newEntry);
        }
        const signals = detectThinkingOutLoudSignals(newEntry.transcript);
        if (qualifiesForClarityPrompt(signals)) {
          writeEnqueueThoughtPatternExtract({
            entryId: newEntry.id,
            transcript: newEntry.transcript,
          });
        }
        finalizeEntry(newEntry);
      } catch (processingError) {
        processingRef.current = false;
        if (
          (isNetworkFetchError(processingError) || isLikelyOffline()) &&
          lastRecordingRef.current
        ) {
          await saveOfflineRecordingDraft(
            blob,
            durationSeconds,
            mimeTypeRef.current,
          );
          setState("error");
          setPendingOfflineRetry(true);
          setNotice(OFFLINE_TRANSCRIPTION_SAVED_COPY);
          setError(OFFLINE_TRANSCRIPTION_RETRY_HINT);
          return;
        }
        setState("error");
        const raw =
          processingError instanceof Error
            ? processingError.message
            : "Something went wrong";
        setError(sanitizeRecordingErrorMessage(raw));
      }
    },
    [
      completeClarityAfterSave,
      completeRecordReturnAfterSave,
      finalizeEntry,
      listeningMode,
      quickMode,
      reflectionPrompt,
      saveRecordingBlob,
    ],
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
    setMicBlocked(false);
    setPendingOfflineRetry(false);
    if (densityOffer) {
      recordRecurrenceDensityEngaged();
      setDensityOffer(null);
    }
    chunksRef.current = [];

    markMicPermissionRequestActive();
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      clearMicPermissionRequestActive();
      markMicrophonePermissionGranted();
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
      markRecorderEngaged();
      markReflexRecordingStarted();
      maybeRecordFirstReturnRerecordWithin10Min();
      markRecordingStartedForVulnerability(captureContext);
      markSpeechStartedAfterHesitation();
      clearHesitationWatch();
      recordInterruptionOutcome("recording");
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
      clearMicPermissionRequestActive();
      setMicBlocked(true);
      setState("error");
      setError(null);
    }
  }, [
    clearTimer,
    densityOffer,
    processRecording,
    recoverUnexpectedRecording,
    stopRecording,
    stopTracks,
  ]);

  const retryLastRecording = useCallback(() => {
    const last = lastRecordingRef.current;
    if (last) {
      void processRecording(last.blob, last.durationSeconds);
      return;
    }
    void startRecording();
  }, [processRecording, startRecording]);

  useEffect(() => {
    if (reflexFastBoot) markReflexRecorderMounted();
  }, [reflexFastBoot]);

  useEffect(() => {
    if (
      zeroState ||
      preRecordLine ||
      reflectionPrompt ||
      recordReturnProp ||
      clarityRecordProp ||
      reflexCaptureProp ||
      quickMode
    ) {
      return;
    }
    const id = requestAnimationFrame(() => {
      setDensityOffer(pickRecurrenceDensityPrompt());
    });
    return () => cancelAnimationFrame(id);
  }, [
    clarityRecordProp,
    preRecordLine,
    quickMode,
    recordReturnProp,
    reflexCaptureProp,
    reflectionPrompt,
  ]);

  useEffect(() => {
    const wantsAutoStart =
      autoStart || Boolean(recordReturnProp || clarityRecordProp || reflexCaptureProp);
    if (!wantsAutoStart) return;
    void (async () => {
      if (await isMicrophonePermissionGranted()) {
        void startRecording();
      }
    })();
  }, [
    autoStart,
    clarityRecordProp,
    recordReturnProp,
    reflexCaptureProp,
    startRecording,
  ]);

  useEffect(() => {
    setRecorderSurfaceActive(true);
    observeFunnelRecorderViewed();
    return () => setRecorderSurfaceActive(false);
  }, []);

  useEffect(() => {
    return () => {
      clearTimer();
      stopTracks();
      if (recorderStartedRef.current && !recorderCompletedRef.current) {
        markRecorderAbandoned();
        const ctx = peekRecordReturnContext();
        if (ctx) recordResurfacingOpenedWithoutReflection(ctx.noteId);
        const clarityCtx = peekClarityRecordContext();
        if (clarityCtx) writeTrackClarityAbandoned(clarityCtx.entryId);
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

  const canShowRecorderCta = usePrimaryCtaClaim("recorder", state === "idle");
  const canShowRetryCta = usePrimaryCtaClaim("retry", state === "error");
  const activeClarity = clarityRecordProp ?? clarityRecordRef.current;
  const activeReflex = reflexCaptureProp ?? reflexCaptureRef.current;
  const activeReturn =
    recordReturnProp ??
    recordReturnRef.current ??
    (reflectionPrompt
      ? {
          id: "legacy-return",
          anchorQuote: reflectionPrompt,
          noteId: "legacy-return",
          source: "resurfacing" as const,
        }
      : null);

  return (
    <div className="mobile-recorder-zone mobile-recorder-dominant w-full max-w-xl px-2">
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
            {canShowRecorderCta && activeReflex ? (
              <div className="flex w-full max-w-md flex-col items-center gap-5">
                <p className="max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
                  {activeReflex.continuityLine}
                </p>
                <Button
                  type="button"
                  size="lg"
                  className="mobile-touch-target mobile-recorder-primary min-h-[3.25rem] min-w-[13rem] text-base"
                  data-primary-cta="recorder"
                  onClick={() => void startRecording()}
                >
                  <Mic className="h-5 w-5" />
                  Record
                </Button>
              </div>
            ) : canShowRecorderCta && activeClarity ? (
              <div className="flex w-full max-w-md flex-col items-center gap-5">
                <p className="text-center text-lg font-normal leading-relaxed text-zinc-300">
                  {activeClarity.recorderPrompt}
                </p>
                <Button
                  type="button"
                  size="lg"
                  className="mobile-touch-target mobile-recorder-primary min-h-[3.25rem] min-w-[13rem] text-base"
                  data-primary-cta="recorder"
                  onClick={() => void startRecording()}
                >
                  <Mic className="h-5 w-5" />
                  Record
                </Button>
              </div>
            ) : canShowRecorderCta && activeReturn && !zeroState ? (
              <RecordReturnAnchor
                context={activeReturn}
                onRecordAgain={() => void startRecording()}
              />
            ) : canShowRecorderCta && activeReturn && zeroState ? (
              <div className="flex w-full max-w-md flex-col items-center gap-5">
                <p className="max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
                  {activeReturn.anchorQuote}
                </p>
                <Button
                  type="button"
                  size="lg"
                  className="mobile-touch-target mobile-recorder-primary min-h-[3.25rem] min-w-[13rem] text-base"
                  data-primary-cta="recorder"
                  onClick={() => void startRecording()}
                >
                  <Mic className="h-5 w-5" />
                  Record
                </Button>
              </div>
            ) : canShowRecorderCta ? (
              <>
                <Button
                  size="lg"
                  className="mobile-touch-target mobile-recorder-primary min-h-[3.25rem] min-w-[13rem] text-base"
                  data-primary-cta="recorder"
                  onClick={() => void startRecording()}
                >
                  <Mic className="h-5 w-5" />
                  {quickMode ? RECORDER_PRIMARY_LABEL : "Start reflection"}
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
            ) : null}
            {!activeReturn && !activeClarity && !activeReflex && !quickMode ? (
              <p className="text-sm text-zinc-500">{ONBOARDING_RECORDER.idle}</p>
            ) : null}
          </motion.div>
        )}

        {state === "recording" && (
          <motion.div
            key="recording"
            variants={presenceFade}
            initial="initial"
            animate="animate"
            exit="exit"
            className="flex flex-col items-center gap-7 px-4 py-10"
          >
            {activeReflex ? (
              <p className="max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
                {activeReflex.continuityLine}
              </p>
            ) : activeClarity ? (
              <p className="max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
                {activeClarity.recorderPrompt}
              </p>
            ) : activeReturn ? (
              <div className="max-w-sm text-center">
                <p className="text-xs tracking-wide text-zinc-600">
                  You're returning to this:
                </p>
                <p className="mt-2 text-sm leading-[1.75] text-zinc-400/95">
                  {activeReturn.anchorQuote}
                </p>
              </div>
            ) : null}
            <div className="relative flex h-28 w-28 items-center justify-center">
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
              {!quickMode ? (
                <p className="mt-2 text-sm leading-relaxed text-zinc-500">
                  {listeningMode ? "Speak freely" : "Speak freely"}
                </p>
              ) : null}
            </div>

            <Button
              variant="destructive"
              size="lg"
              className="mobile-touch-target min-w-[11rem]"
              onClick={stopRecording}
            >
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
            {quickMode && liveTranscript ? (
              <p className="mb-4 max-w-md text-center text-sm leading-[1.75] text-zinc-400/95">
                {liveTranscript}
              </p>
            ) : null}
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
            {continuityLine ? (
              <p className="mt-3 text-sm leading-[1.75] text-zinc-400/95">
                {continuityLine}
              </p>
            ) : null}
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
            {micBlocked ? (
              <MicPermissionPanel
                onRetry={() => {
                  setMicBlocked(false);
                  void startRecording();
                }}
              />
            ) : (
              <>
                {notice ? (
                  <p className="text-center text-sm leading-relaxed text-zinc-300">
                    {notice}
                  </p>
                ) : null}
                {error && !pendingOfflineRetry ? (
                  <ErrorBanner message={error} />
                ) : error ? (
                  <p className="text-center text-sm leading-relaxed text-zinc-500">
                    {error}
                  </p>
                ) : null}
                {canShowRetryCta ? (
                  <div className="flex justify-center">
                    <Button
                      data-primary-cta="retry"
                      onClick={() =>
                        pendingOfflineRetry
                          ? void retryLastRecording()
                          : void startRecording()
                      }
                    >
                      {pendingOfflineRetry
                        ? "Retry transcription"
                        : MIC_PERMISSION_COPY.retry}
                    </Button>
                  </div>
                ) : null}
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
