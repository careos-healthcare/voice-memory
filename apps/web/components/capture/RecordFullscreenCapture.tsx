"use client";

import { useEffect, type ReactNode } from "react";

/** Full-screen capture chrome — dark only, no nav/footer slots. */
export function RecordFullscreenCapture({ children }: { children: ReactNode }) {
  useEffect(() => {
    document.body.dataset.recordCapture = "true";
    return () => {
      delete document.body.dataset.recordCapture;
    };
  }, []);

  return (
    <div
      className="record-fullscreen-capture fixed inset-0 z-50 flex flex-col overflow-hidden bg-zinc-950 text-zinc-100"
      data-record-capture="true"
    >
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute left-1/2 top-0 h-[360px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/25 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-[240px] w-[240px] rounded-full bg-fuchsia-600/10 blur-3xl" />
      </div>
      <div className="relative mx-auto flex min-h-0 w-full max-w-xl flex-1 flex-col px-4 pb-safe pt-safe sm:px-6">
        {children}
      </div>
    </div>
  );
}
