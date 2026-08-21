"use client";

import { ZeroStateRecorderShell } from "@/archived-components/_archived/capture/ZeroStateRecorderShell";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";

/** Silence-first or direct-to-mic — zero-state recorder only. */
export function MicCentricHome({
  continuityLine,
  recordReturn,
  clarityRecord,
  reflexCapture,
  recorderAutoStart,
  quickReflection,
}: {
  continuityLine: string | null;
  recordReturn: RecordReturnContext | null;
  clarityRecord: ClarityRecordContext | null;
  reflexCapture: ReflexCaptureContext | null;
  recorderAutoStart: boolean;
  quickReflection?: boolean;
}) {
  return (
    <div className="flex min-h-[70vh] flex-col items-center justify-center py-8">
      <ZeroStateRecorderShell
        route="home"
        recordReturn={recordReturn}
        clarityRecord={clarityRecord}
        reflexCapture={reflexCapture}
        preserveQuote={continuityLine}
        captureContext="home_mic_centric"
        autoStartOverride={recorderAutoStart}
        quickReflection={quickReflection}
      />
    </div>
  );
}
