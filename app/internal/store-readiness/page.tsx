import Link from "next/link";

import { StoreReadinessPanel } from "@/components/internal/StoreReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildMobilePrimaryPlatformReport } from "@/lib/mobile/mobile-primary-platform";

export default function StoreReadinessPage() {
  const platform = buildMobilePrimaryPlatformReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Store distribution readiness
          </h1>
          <p className="mt-2 text-sm text-zinc-400">
            TestFlight and Play internal are evidence, not assumptions. Commit JSON after physical
            signing, upload, install, purchase, and restore.
          </p>
          <p className="mt-3 text-sm">
            {platform.verdictLabel}:{" "}
            <span className="font-medium text-amber-300">{platform.verdict}</span>
          </p>
        </header>

        <div className="mt-6">
          <StoreReadinessPanel />
        </div>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
          <Link href="/internal/launch" className="text-violet-300 hover:text-violet-200">
            Launch command center →
          </Link>
        </div>
      </div>
    </div>
  );
}
