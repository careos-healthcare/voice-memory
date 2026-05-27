import type { ReactNode } from "react";

/** Full-screen capture chrome — dark only, no nav/footer slots. */
export function RecordFullscreenCapture({ children }: { children: ReactNode }) {
  return (
    <div
      className="record-fullscreen-capture relative min-h-screen-mobile overflow-hidden bg-zinc-950 text-zinc-100 pb-safe"
      data-record-capture="true"
    >
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute left-1/2 top-0 h-[360px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/25 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[240px] w-[240px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>
      <div className="relative mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 sm:px-6">
        {children}
      </div>
    </div>
  );
}
