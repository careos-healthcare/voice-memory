import Link from "next/link";

import { CommercialReadinessPanel } from "@/archived-components/_archived/internal/CommercialReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildGooglePlayReadinessReport } from "@/lib/mobile/commercial-evidence";
import { buildMobilePrimaryPlatformReport } from "@/lib/mobile/mobile-primary-platform";

export default function GooglePlayReadinessPage() {
  const report = buildGooglePlayReadinessReport();
  const platform = buildMobilePrimaryPlatformReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Google Play readiness
          </h1>
          <p className="mt-2 text-sm text-zinc-400">
            Signing, internal track, billing, restore, push — evidence only.
          </p>
          <p className="mt-3 text-sm">
            {platform.verdictLabel}:{" "}
            <span className="font-medium text-amber-300">{platform.verdict}</span>
          </p>
        </header>

        <div className="mt-6">
          <CommercialReadinessPanel report={report} title="Google Play" />
        </div>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link
            href="/internal/store-readiness"
            className="text-violet-300 hover:text-violet-200"
          >
            Store distribution evidence →
          </Link>
          <Link
            href="/internal/apple-store-readiness"
            className="text-violet-300 hover:text-violet-200"
          >
            Apple store readiness →
          </Link>
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
        </div>
      </div>
    </div>
  );
}
