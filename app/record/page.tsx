"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { Recorder } from "@/components/Recorder";
import { SiteHeader } from "@/components/SiteHeader";
import {
  consumeQuickEntryContexts,
  parseQuickEntryIntent,
} from "@/lib/mobile/quick-entry";
import { markReflexPageLand, markReflexRecorderMounted } from "@/lib/reflex/reflex-observation";
import { recordReflexAppOpen } from "@/lib/reflex/open-without-record";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";
import { useState } from "react";

/** Fast-open route — mic-first, minimal chrome. */
export default function QuickRecordPage() {
  const router = useRouter();
  const [recordReturn, setRecordReturn] = useState<RecordReturnContext | null>(null);
  const [clarityRecord, setClarityRecord] = useState<ClarityRecordContext | null>(null);
  const [reflexContext, setReflexContext] = useState<ReflexCaptureContext | null>(null);
  const [continuityLine, setContinuityLine] = useState<string | null>(null);
  const [autoStart, setAutoStart] = useState(true);

  useEffect(() => {
    markReflexPageLand();
    recordReflexAppOpen();
    const resolution = parseQuickEntryIntent();
    const consumed = consumeQuickEntryContexts();
    setRecordReturn(consumed.recordReturn);
    setClarityRecord(consumed.clarity);
    setReflexContext(consumed.reflex ?? resolution.reflexContext);
    setContinuityLine(
      consumed.reflex?.continuityLine ??
        resolution.reflexContext?.continuityLine ??
        resolution.preserveQuote,
    );
    setAutoStart(resolution.autoStart);
    markReflexRecorderMounted();
  }, []);

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 pb-10 sm:px-6">
        <SiteHeader />
        <main className="flex flex-1 flex-col items-center justify-center py-8">
          {continuityLine ? (
            <p className="mb-6 max-w-sm text-center text-sm leading-[1.75] text-zinc-400/95">
              {continuityLine}
            </p>
          ) : null}
          <Recorder
            autoStart={autoStart}
            recordReturn={recordReturn}
            clarityRecord={clarityRecord}
            reflexCapture={reflexContext}
            reflexFastBoot
            onComplete={() => router.push("/")}
          />
        </main>
      </div>
    </div>
  );
}
