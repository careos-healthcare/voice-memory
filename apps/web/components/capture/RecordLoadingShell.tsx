import { Mic } from "lucide-react";

import { RecordFullscreenCapture } from "@/components/capture/RecordFullscreenCapture";

/** Dark mic shell for /record Suspense and route loading — never white or raw HTML. */
export function RecordLoadingShell() {
  return (
    <RecordFullscreenCapture>
      <main className="mobile-recorder-dominant flex flex-1 flex-col items-center justify-center py-8">
        <div className="relative flex h-[4.5rem] w-[4.5rem] items-center justify-center">
          <span
            className="absolute inset-0 animate-pulse rounded-full bg-red-500/15"
            aria-hidden
          />
          <span className="relative flex h-16 w-16 items-center justify-center rounded-full bg-red-500/90 shadow-lg shadow-red-500/20">
            <Mic className="h-7 w-7 text-white" aria-hidden />
          </span>
        </div>
        <p className="mt-6 text-sm leading-relaxed text-zinc-400">Opening recorder…</p>
      </main>
    </RecordFullscreenCapture>
  );
}
