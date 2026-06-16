import Link from "next/link";

import { ArchiveAsProductValidationPanel } from "@/components/internal/ArchiveAsProductValidationPanel";
import { ArchiveBeliefAdoptionPanel } from "@/components/internal/ArchiveBeliefAdoptionPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildArchiveBeliefAdoptionReport } from "@/lib/metrics/archive-belief-adoption-report";

export default function ArchiveBeliefInternalPage() {
  const report = buildArchiveBeliefAdoptionReport();

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Archive belief</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Archive Belief Adoption
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Roadmap freeze: prove users think Archive is the product — not a journal or insight
            tool. Device signals + founder interviews below. Build History only after these four
            gates move.
          </p>
        </header>

        <div className="mt-6 space-y-8">
          <ArchiveAsProductValidationPanel />
          <ArchiveBeliefAdoptionPanel report={report} />
        </div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/discover" className="text-violet-300 hover:text-violet-200">
            Discover (belief card) →
          </Link>
          <Link href="/internal/archive-voice" className="text-zinc-500 hover:text-zinc-300">
            Archive voice →
          </Link>
        </div>
      </div>
    </div>
  );
}
