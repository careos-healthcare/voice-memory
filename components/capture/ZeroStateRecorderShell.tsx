"use client";

import { useEffect, useLayoutEffect, useMemo, useState } from "react";

import {
  RecordCaptureChrome,
  type RecordUiPhase,
} from "@/components/capture/RecordCaptureChrome";
import { Recorder } from "@/components/Recorder";
import { getStoredEntryCount } from "@/lib/storage";
import { markAppOpenForCapture, markFastCaptureReady } from "@/lib/capture/fast-capture";
import { setRecorderSurfaceActive } from "@/lib/mobile/install-prompt-gate";
import { markMicVisibleForHesitation } from "@/lib/capture/hesitation-signals";
import {
  getZeroStateRecorderLine,
  shouldAutoStartZeroStateRecorder,
  shouldUseZeroStateRecorder,
  type ZeroStateRecorderInput,
} from "@/lib/capture/zero-state-recorder";
import {
  markMicVisible,
  startVulnerabilitySession,
} from "@/lib/capture/vulnerability-timing";
import {
  RECORD_SCREEN_HEADLINE,
  RECORD_SCREEN_SECONDARY,
  RECORD_SCREEN_SUBTEXT,
} from "@/lib/archive/archive-record-copy";
import { markReflexRecorderMounted } from "@/lib/reflex/reflex-observation";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";

/** Mic-first shell — recorder visible immediately, max one line above mic. */
export function ZeroStateRecorderShell({
  route = "record",
  recordReturn = null,
  clarityRecord = null,
  reflexCapture = null,
  preserveQuote = null,
  captureContext = "record",
  autoStartOverride,
  onComplete,
  quickReflection,
}: {
  route?: ZeroStateRecorderInput["route"];
  recordReturn?: RecordReturnContext | null;
  clarityRecord?: ClarityRecordContext | null;
  reflexCapture?: ReflexCaptureContext | null;
  preserveQuote?: string | null;
  captureContext?: string;
  autoStartOverride?: boolean;
  onComplete?: () => void;
  quickReflection?: boolean;
}) {
  const input = useMemo(
    () => ({
      route,
      recordReturn,
      clarityRecord,
      reflexCapture,
      preserveQuote,
    }),
    [route, recordReturn, clarityRecord, reflexCapture, preserveQuote],
  );

  const line = getZeroStateRecorderLine(input);
  const autoStart =
    autoStartOverride ?? shouldAutoStartZeroStateRecorder(input);
  const zeroState = shouldUseZeroStateRecorder(input);
  const [phase, setPhase] = useState<RecordUiPhase>("ready");
  const firstTime = useMemo(() => getStoredEntryCount() === 0, []);

  useLayoutEffect(() => {
    setRecorderSurfaceActive(true);
    markAppOpenForCapture();
    startVulnerabilitySession(captureContext);
    markReflexRecorderMounted();
    markMicVisibleForHesitation();
    markMicVisible(captureContext);
    markFastCaptureReady();
    return () => setRecorderSurfaceActive(false);
  }, [captureContext]);

  const showRecordFraming = route === "record" && phase === "ready";

  return (
    <div className="mobile-recorder-dominant flex w-full max-w-lg flex-col items-center justify-center gap-6 py-6">
      {showRecordFraming ? (
        <header className="max-w-sm text-center" data-testid="record-screen-framing">
          <h2 className="text-xl font-medium tracking-tight text-zinc-100 sm:text-2xl">
            {RECORD_SCREEN_HEADLINE}
          </h2>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{RECORD_SCREEN_SUBTEXT}</p>
          <p className="mt-1 text-xs leading-relaxed text-zinc-600">{RECORD_SCREEN_SECONDARY}</p>
        </header>
      ) : null}
      <RecordCaptureChrome
        phase={phase}
        showFirstTimeHint={firstTime && phase === "ready"}
      />
      {line ? (
        <p className="max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">{line}</p>
      ) : null}
      <Recorder
        autoStart={autoStart}
        recordReturn={recordReturn}
        clarityRecord={clarityRecord}
        reflexCapture={reflexCapture}
        reflexFastBoot
        zeroState={zeroState}
        quickReflection={quickReflection}
        onComplete={onComplete}
        onUiPhaseChange={setPhase}
      />
    </div>
  );
}
