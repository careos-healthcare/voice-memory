import Link from "next/link";

import { SiteHeader } from "@/components/SiteHeader";

export default function OfflinePage() {
  return (
    <div className="min-h-screen-mobile bg-zinc-950">
      <div className="mx-auto max-w-lg px-4 pb-20 pt-2 sm:px-6">
        <SiteHeader />
        <main id="main-content" className="mt-16 space-y-4 text-center">
          <h1 className="text-xl font-normal text-zinc-200">You&apos;re offline</h1>
          <p className="text-sm leading-relaxed text-muted">
            VoiceMemory needs a connection for the first load. Your reflections stay on this
            device when you&apos;ve opened the app before.
          </p>
          <Link href="/" className="inline-block text-sm text-violet-300 hover:text-violet-200">
            Try again
          </Link>
        </main>
      </div>
    </div>
  );
}
