"use client";

import { Recorder } from "@/components/Recorder";
import { REFLEX_SILENCE_FIRST_LINE } from "@/lib/reflex/reflex-copy";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";

/** Silence-first or direct-to-mic — mic + at most one line. */
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
  const line = continuityLine ?? REFLEX_SILENCE_FIRST_LINE;

  return (
    <div className="flex min-h-[70vh] flex-col items-center justify-center py-8">
      <p className="mb-8 max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
        {line}
      </p>
      <Recorder
        autoStart={recorderAutoStart}
        recordReturn={recordReturn}
        clarityRecord={clarityRecord}
        reflexCapture={reflexCapture}
        reflexFastBoot
        quickReflection={quickReflection}
      />
    </div>
  );
}
