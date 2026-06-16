import Link from "next/link";

import { MobileProductionReadinessPanel } from "@/components/internal/MobileProductionReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildMobileProductionReadinessReport } from "@/lib/mobile/mobile-production-readiness";
import { evidenceDirPath } from "@/lib/mobile/release-evidence";

export default function MobileReadinessPage() {
  const report = buildMobileProductionReadinessReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Mobile production readiness
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Store-ready proof for ArchiveMe Flutter — push, signing, billing, distribution. No new
            product intelligence; evidence files only.
          </p>
        </header>

        <div className="mt-6">
          <MobileProductionReadinessPanel report={report} />
        </div>

        <p className="mt-6 text-xs text-zinc-600">
          Evidence directory: <code className="text-zinc-500">{evidenceDirPath()}</code>
        </p>
        <p className="mt-2 text-xs text-zinc-600">
          Report: <code className="text-zinc-500">docs/MOBILE_READINESS_REPORT.md</code> (generate via{" "}
          <code className="text-zinc-500">npm run generate:mobile-readiness-report</code>)
        </p>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-parity" className="text-violet-300 hover:text-violet-200">
            Mobile parity →
          </Link>
          <Link
            href="/internal/mobile-archive-review"
            className="text-violet-300 hover:text-violet-200"
          >
            Archive-first mobile review →
          </Link>
          <Link
            href="/internal/mobile-push-readiness"
            className="text-violet-300 hover:text-violet-200"
          >
            Native push readiness →
          </Link>
          <Link
            href="/internal/revenuecat-verification"
            className="text-violet-300 hover:text-violet-200"
          >
            RevenueCat verification →
          </Link>
          <Link
            href="/internal/restore-verification"
            className="text-violet-300 hover:text-violet-200"
          >
            Restore verification →
          </Link>
          <Link href="/internal/archive" className="text-violet-300 hover:text-violet-200">
            Founder dashboard →
          </Link>
          <Link href="/internal/north-star" className="text-violet-300 hover:text-violet-200">
            North star →
          </Link>
        </div>
      </div>
    </div>
  );
}
