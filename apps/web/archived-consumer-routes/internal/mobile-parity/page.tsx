import Link from "next/link";

import { MobileFirstClassPanel } from "@/archived-components/_archived/internal/MobileFirstClassPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildMobileFirstClassReport } from "@/lib/mobile/mobile-first-class-report";

export default function MobileParityPage() {
  const report = buildMobileFirstClassReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Mobile feature parity
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Archive features on Flutter vs web — MISSING, PARTIAL, or COMPLETE from repo evidence.
            Not a companion checklist.
          </p>
        </header>

        <div className="mt-6">
          <MobileFirstClassPanel report={report} variant="parity" />
        </div>

        <p className="mt-6 text-xs text-zinc-600">
          Report file:{" "}
          <code className="text-zinc-500">docs/MOBILE_PARITY_REPORT.md</code> (
          <code className="text-zinc-500">npm run generate:mobile-parity-report</code>)
        </p>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link
            href="/internal/mobile-archive-review"
            className="text-violet-300 hover:text-violet-200"
          >
            Archive-first mobile review →
          </Link>
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
        </div>
      </div>
    </div>
  );
}
