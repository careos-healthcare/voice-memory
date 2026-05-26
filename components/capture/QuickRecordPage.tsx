"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { ZeroStateRecorderShell } from "@/components/capture/ZeroStateRecorderShell";
import {
  markAppOpenForCapture,
  shouldAutoStartWithMicPermission,
  warmFastCaptureShell,
} from "@/lib/capture/fast-capture";
import { shouldForceDirectMicNextSession } from "@/lib/capture/hesitation-signals";
import {
  consumeQuickEntryContexts,
  parseQuickEntryIntent,
  parseQuickEntryPreview,
  type QuickEntryResolution,
} from "@/lib/mobile/quick-entry";
import { markReflexPageLand } from "@/lib/reflex/reflex-observation";
import { recordReflexAppOpen } from "@/lib/reflex/open-without-record";
import type { ClarityRecordContext } from "@/lib/clarity/clarity-record";
import type { RecordReturnContext } from "@/types/record-return";
import type { ReflexCaptureContext } from "@/lib/reflex/reflex-context";

/** Primary fast capture route — mic visible on first paint, hydration deferred. */
export function QuickRecordPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const search = searchParams.toString();

  const preview = useMemo(
    () => parseQuickEntryPreview(search ? `?${search}` : ""),
    [search],
  );

  const [resolution, setResolution] = useState<QuickEntryResolution | null>(null);
  const [recordReturn, setRecordReturn] = useState<RecordReturnContext | null>(
    preview.recordReturn,
  );
  const [clarityRecord, setClarityRecord] = useState<ClarityRecordContext | null>(
    preview.clarityRecord,
  );
  const [reflexContext, setReflexContext] = useState<ReflexCaptureContext | null>(
    preview.reflexContext,
  );
  const [preserveQuote, setPreserveQuote] = useState<string | null>(preview.preserveQuote);
  const [autoStart, setAutoStart] = useState(
    shouldAutoStartWithMicPermission(preview.autoStart),
  );

  useEffect(() => {
    markAppOpenForCapture();
    warmFastCaptureShell();
    markReflexPageLand();
    recordReflexAppOpen();

    const next = parseQuickEntryIntent({
      pathname: "/record",
      search: search ? `?${search}` : "",
      hash: "",
    });
    const consumed = consumeQuickEntryContexts();
    setResolution(next);
    setRecordReturn(consumed.recordReturn ?? next.recordReturn);
    setClarityRecord(consumed.clarity ?? preview.clarityRecord);
    setReflexContext(consumed.reflex ?? next.reflexContext);
    setPreserveQuote(
      next.preserveQuote ?? consumed.recordReturn?.anchorQuote ?? preview.preserveQuote,
    );
    setAutoStart(shouldAutoStartWithMicPermission(next.autoStart));
  }, [search, preview.clarityRecord, preview.preserveQuote]);

  useEffect(() => {
    if (!shouldForceDirectMicNextSession()) return;
    setPreserveQuote(null);
    setRecordReturn(null);
    setClarityRecord(null);
  }, []);

  const captureContext = resolution?.source ?? preview.source ?? "record";

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 pb-10 sm:px-6">
        <main className="flex flex-1 flex-col justify-center">
          <ZeroStateRecorderShell
            route="record"
            recordReturn={recordReturn}
            clarityRecord={clarityRecord}
            reflexCapture={reflexContext}
            preserveQuote={preserveQuote}
            captureContext={captureContext}
            autoStartOverride={autoStart}
            onComplete={() => {
              const entryId = resolution?.entryId ?? preview.entryId;
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
