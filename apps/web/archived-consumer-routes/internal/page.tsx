import Link from "next/link";

import { InternalCommandCenter } from "@/archived-components/_archived/internal/InternalCommandCenter";
import { SiteHeader } from "@/components/SiteHeader";

export default function InternalCommandCenterPage() {
  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />

      <header className="mt-2">
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder</p>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
          Internal command center
        </h1>
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
          Activation, return, conversion, distribution, and mobile readiness — answer five
          questions in under a minute.
        </p>
      </header>

      <div className="mt-8">
        <InternalCommandCenter />
      </div>

      <p className="mt-10 text-sm">
        <Link href="/" className="text-zinc-500 hover:text-zinc-300">
          ← Product
        </Link>
      </p>
    </div>
  );
}
