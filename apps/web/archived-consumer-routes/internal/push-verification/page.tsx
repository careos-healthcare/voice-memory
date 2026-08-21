import Link from "next/link";

import { PushVerificationPanel } from "@/archived-components/_archived/internal/PushVerificationPanel";
import { SiteHeader } from "@/components/SiteHeader";

export default function PushVerificationPage() {
  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Push notification verification
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Prove the full path: permission → delivery → tap → correct screen. Events are stored on
            this device only.
          </p>
        </header>

        <div className="mt-6">
          <PushVerificationPanel />
        </div>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
          <Link href="/internal/archive" className="text-violet-300 hover:text-violet-200">
            Founder dashboard →
          </Link>
        </div>
      </div>
    </div>
  );
}
