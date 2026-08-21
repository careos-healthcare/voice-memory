import Link from "next/link";

import { MobileFirstClassPanel } from "@/archived-components/_archived/internal/MobileFirstClassPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildMobileFirstClassReport } from "@/lib/mobile/mobile-first-class-report";

export default function MobileArchiveReviewPage() {
  const report = buildMobileFirstClassReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Archive-first mobile review
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Can a user understand, trust, change, protect, subscribe, and restore the archive entirely
            from the Flutter app?
          </p>
          <p className="mt-3 text-sm">
            Verdict:{" "}
            <span
              className={
                report.verdict === "PRIMARY_PLATFORM"
                  ? "font-medium text-emerald-400"
                  : "font-medium text-amber-300"
              }
            >
              {report.verdict}
            </span>
          </p>
        </header>

        <div className="mt-6">
          <MobileFirstClassPanel report={report} variant="archive-review" />
        </div>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-parity" className="text-violet-300 hover:text-violet-200">
            Feature parity →
          </Link>
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Distribution score →
          </Link>
        </div>
      </div>
    </div>
  );
}
