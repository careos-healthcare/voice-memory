"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { ZeroStateRecorderShell } from "@/components/capture/ZeroStateRecorderShell";
import {
  consumeQuickEntryContexts,
  parseQuickEntryIntent,
  type QuickEntryResolution,
} from "@/lib/mobile/quick-entry";
import { markReflexPageLand } from "@/lib/reflex/reflex-observation";
import { recordReflexAppOpen } from "@/lib/reflex/open-without-record";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";

/** Primary fast capture route — mic dominant within ~1s. */
export function QuickRecordPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [resolution, setResolution] = useState<QuickEntryResolution | null>(null);
  const [recordReturn, setRecordReturn] = useState<RecordReturnContext | null>(null);
  const [clarityRecord, setClarityRecord] = useState<ClarityRecordContext | null>(null);
  const [reflexContext, setReflexContext] = useState<ReflexCaptureContext | null>(null);

  useEffect(() => {
    markReflexPageLand();
    recordReflexAppOpen();
    const next = parseQuickEntryIntent({
      pathname: "/record",
      search: `?${searchParams.toString()}`,
      hash: "",
    });
    const consumed = consumeQuickEntryContexts();
    setResolution(next);
    setRecordReturn(consumed.recordReturn ?? next.recordReturn);
    setClarityRecord(consumed.clarity);
    setReflexContext(consumed.reflex ?? next.reflexContext);
  }, [searchParams]);

  const captureContext = resolution?.source ?? "record";

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 pb-10 sm:px-6">
        <main className="flex flex-1 flex-col justify-center">
          <ZeroStateRecorderShell
            route="record"
            recordReturn={recordReturn}
            clarityRecord={clarityRecord}
            reflexCapture={reflexContext}
            preserveQuote={resolution?.preserveQuote ?? null}
            captureContext={captureContext}
            autoStartOverride={resolution?.autoStart ?? true}
            onComplete={() => {
              const entryId = resolution?.entryId;
              if (entryId) {
                router.push(`/entry/${entryId}`);
                return;
              }
              router.push("/");
            }}
            quickReflection
          />
        </main>
      </div>
    </div>
  );
}
