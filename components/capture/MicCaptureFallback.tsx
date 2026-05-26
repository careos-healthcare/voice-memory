/** Static mic shell for Suspense — no shimmer, no continuity. */
export function MicCaptureFallback() {
  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 pb-10 sm:px-6">
        <main className="mobile-recorder-dominant flex flex-1 flex-col items-center justify-center py-6">
          <div
            className="h-[4.5rem] w-[4.5rem] rounded-full border border-violet-500/30 bg-violet-950/40"
            aria-hidden
          />
          <p className="sr-only">Recorder loading</p>
        </main>
      </div>
    </div>
  );
}
